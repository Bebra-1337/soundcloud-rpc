#include "integrations/DiscordIpc.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocalSocket>
#include <QTimer>
#include <QUuid>
#include <QtEndian>

#ifdef Q_OS_UNIX
#include <unistd.h>
#endif

static constexpr int kRateLimitCount = 4;
static constexpr qint64 kRateLimitWindowMs = 20000;
static constexpr qint64 kSettleDelayMs = 250;
static constexpr int kReconnectMs = 5000;

enum Opcode : quint32 { Handshake = 0, Frame = 1, Close = 2, Ping = 3, Pong = 4 };

bool DiscordActivity::same(const DiscordActivity &o) const
{
    if (details != o.details || state != o.state || largeImage != o.largeImage || smallImage != o.smallImage
        || largeText != o.largeText || buttonUrl != o.buttonUrl || buttonLabel != o.buttonLabel)
        return false;
    // playing activities carry timestamps: only resend when the start moved (seek) or the end changed
    auto close = [](qint64 a, qint64 b) { return (a == 0) == (b == 0) && std::abs(a - b) <= 1500; };
    return close(start, o.start) && close(end, o.end);
}

QJsonObject DiscordActivity::toJson() const
{
    QJsonObject a{{QStringLiteral("type"), 2}};  // LISTENING
    if (!details.isEmpty())
        a[QStringLiteral("details")] = details;
    if (!state.isEmpty())
        a[QStringLiteral("state")] = state;
    if (start) {
        QJsonObject ts{{QStringLiteral("start"), start}};
        if (end)
            ts[QStringLiteral("end")] = end;
        a[QStringLiteral("timestamps")] = ts;
    }
    QJsonObject assets;
    if (!largeImage.isEmpty())
        assets[QStringLiteral("large_image")] = largeImage;
    if (!largeText.isEmpty())
        assets[QStringLiteral("large_text")] = largeText;
    if (!smallImage.isEmpty())
        assets[QStringLiteral("small_image")] = smallImage;
    if (!smallText.isEmpty())
        assets[QStringLiteral("small_text")] = smallText;
    if (!assets.isEmpty())
        a[QStringLiteral("assets")] = assets;
    if (!buttonUrl.isEmpty())
        a[QStringLiteral("buttons")] = QJsonArray{QJsonObject{{QStringLiteral("label"), buttonLabel},
                                                              {QStringLiteral("url"), buttonUrl}}};
    return a;
}

DiscordIpc::DiscordIpc(const QString &clientId, QObject *parent)
    : QObject(parent), m_clientId(clientId), m_socket(new QLocalSocket(this)), m_wake(new QTimer(this)),
      m_reconnect(new QTimer(this))
{
    m_clock.start();
    m_wake->setSingleShot(true);
    connect(m_wake, &QTimer::timeout, this, &DiscordIpc::process);
    m_reconnect->setSingleShot(true);
    connect(m_reconnect, &QTimer::timeout, this, [this] {
        m_candidates.clear();
        connectNext();
    });

    connect(m_socket, &QLocalSocket::connected, this, &DiscordIpc::onConnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &DiscordIpc::onReadyRead);
    connect(m_socket, &QLocalSocket::disconnected, this, &DiscordIpc::onLost);
    connect(m_socket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        if (m_state == Connecting) {
            connectNext();  // try the next socket path
        } else if (m_socket->state() == QLocalSocket::UnconnectedState) {
            onLost();
        }
    });

    QMetaObject::invokeMethod(this, &DiscordIpc::connectNext, Qt::QueuedConnection);
}

DiscordIpc::~DiscordIpc()
{
    if (m_state == Ready)
        writeFrame(Close, {});
    m_socket->disconnect(this);
    m_socket->abort();
}

void DiscordIpc::setActivity(const DiscordActivity &activity)
{
    // only a real change restarts the settle timer, so the periodic refresh can't starve sending
    if (!m_desired || !activity.same(*m_desired))
        m_changedAt = m_clock.elapsed();
    m_desired = activity;
    m_dirty = true;
    process();
}

static QStringList socketCandidates()
{
    QStringList out;
#ifdef Q_OS_WIN
    // Discord listens on named pipes (\\.\pipe\discord-ipc-N); QLocalSocket takes the bare name and they can't be
    // probed as files, so every index is a candidate
    for (int i = 0; i < 10; ++i)
        out.append(QStringLiteral("discord-ipc-%1").arg(i));
#else
    QStringList bases;
#ifdef Q_OS_LINUX
    const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR", QStringLiteral("/run/user/%1").arg(getuid()));
    bases.append(runtime);
#endif
    for (const QString &b : {qEnvironmentVariable("TMPDIR"), qEnvironmentVariable("TMP"),
                             qEnvironmentVariable("TEMP"), QStringLiteral("/tmp")}) {
        if (!b.isEmpty() && !bases.contains(b))
            bases.append(b);
    }
#ifdef Q_OS_LINUX
    // Flatpak / Snap builds of Discord and Vesktop keep their socket in their own runtime subdirectory
    for (const char *sub : {"app/com.discordapp.Discord", "app/dev.vencord.Vesktop", "snap.discord"})
        bases.append(runtime + u'/' + QLatin1StringView(sub));
#endif

    for (const QString &b : std::as_const(bases)) {
        for (int i = 0; i < 10; ++i) {
            const QString path = QStringLiteral("%1/discord-ipc-%2").arg(b).arg(i);
            if (QFileInfo::exists(path))
                out.append(path);
        }
    }
#endif
    return out;
}

void DiscordIpc::connectNext()
{
    if (m_state == Handshaking || m_state == Ready)
        return;
    if (m_candidates.isEmpty() && m_state == Disconnected)
        m_candidates = socketCandidates();
    if (m_candidates.isEmpty()) {
        m_state = Disconnected;
        if (!m_waitingLogged) {
            qInfo() << "Waiting for Discord...";
            m_waitingLogged = true;
        }
        scheduleReconnect();
        return;
    }
    m_state = Connecting;
    m_socket->abort();
    m_socket->connectToServer(m_candidates.takeFirst());
}

void DiscordIpc::scheduleReconnect()
{
    if (!m_reconnect->isActive())
        m_reconnect->start(kReconnectMs);
}

void DiscordIpc::onConnected()
{
    m_state = Handshaking;
    m_buffer.clear();
    writeFrame(Handshake, {{QStringLiteral("v"), 1}, {QStringLiteral("client_id"), m_clientId}});
}

void DiscordIpc::onLost()
{
    if (m_state == Disconnected || m_state == Connecting)
        return;
    qInfo() << "Discord RPC connection lost";
    m_state = Disconnected;
    m_candidates.clear();
    m_lastSent.reset();
    scheduleReconnect();
}

void DiscordIpc::onReadyRead()
{
    m_buffer += m_socket->readAll();
    while (m_buffer.size() >= 8) {
        const quint32 op = qFromLittleEndian<quint32>(m_buffer.constData());
        const quint32 len = qFromLittleEndian<quint32>(m_buffer.constData() + 4);
        if (m_buffer.size() < qsizetype(8 + len))
            return;
        const QJsonObject payload = QJsonDocument::fromJson(m_buffer.mid(8, len)).object();
        m_buffer.remove(0, 8 + len);
        handleFrame(op, payload);
    }
}

void DiscordIpc::handleFrame(quint32 op, const QJsonObject &payload)
{
    switch (op) {
    case Frame: {
        const QString evt = payload.value(QLatin1StringView("evt")).toString();
        if (evt == QLatin1StringView("READY")) {
            qInfo() << "Discord RPC connected via" << m_socket->serverName();
            m_state = Ready;
            m_waitingLogged = false;
            m_lastSent.reset();
            m_dirty = m_desired.has_value();
            process();
        } else if (evt == QLatin1StringView("ERROR")) {
            // Discord rejected this payload; the connection is fine, so don't reconnect or retry it
            qWarning() << "Discord rejected activity:"
                       << payload.value(QLatin1StringView("data")).toObject().value(QLatin1StringView("message")).toString();
        }
        break;
    }
    case Ping:
        writeFrame(Pong, payload);
        break;
    case Close:
        qWarning() << "Discord closed the RPC connection:" << payload.value(QLatin1StringView("message")).toString();
        m_socket->abort();
        onLost();
        break;
    default:
        break;
    }
}

void DiscordIpc::writeFrame(quint32 op, const QJsonObject &payload)
{
    const QByteArray body = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    QByteArray frame(8, Qt::Uninitialized);
    qToLittleEndian<quint32>(op, frame.data());
    qToLittleEndian<quint32>(quint32(body.size()), frame.data() + 4);
    m_socket->write(frame + body);
    m_socket->flush();
}

void DiscordIpc::process()
{
    if (m_state != Ready || !m_dirty || !m_desired)
        return;
    if (m_lastSent && m_desired->same(*m_lastSent)) {
        m_dirty = false;
        return;
    }
    const qint64 now = m_clock.elapsed();
    while (!m_sentTimes.isEmpty() && now - m_sentTimes.first() >= kRateLimitWindowMs)
        m_sentTimes.removeFirst();
    qint64 delay = m_changedAt + kSettleDelayMs - now;
    if (m_sentTimes.size() >= kRateLimitCount)
        delay = std::max(delay, m_sentTimes.first() + kRateLimitWindowMs - now);
    if (delay > 0) {
        m_wake->start(int(delay));
        return;
    }

    const QJsonObject args{{QStringLiteral("pid"), qint64(QCoreApplication::applicationPid())},
                           {QStringLiteral("activity"), m_desired->toJson()}};
    writeFrame(Frame, {{QStringLiteral("cmd"), QStringLiteral("SET_ACTIVITY")},
                       {QStringLiteral("args"), args},
                       {QStringLiteral("nonce"), QUuid::createUuid().toString(QUuid::WithoutBraces)}});
    m_lastSent = m_desired;
    m_sentTimes.append(now);
    m_dirty = false;
}
