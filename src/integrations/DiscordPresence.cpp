#include "integrations/DiscordPresence.h"

#include "integrations/DiscordIpc.h"
#include "player/PlayerController.h"

#include <QDateTime>
#include <QTimer>

static const QString kClientId = QStringLiteral("1289606421368799345");  // Discord app with the SoundCloud assets
static const QString kLogo = QStringLiteral("bw-exploring-bordered-white");
static const QString kIcon = QStringLiteral("bw-icon-bordered-white");

DiscordPresence::DiscordPresence(PlayerController *player, QObject *parent)
    : QObject(parent), m_player(player), m_ipc(new DiscordIpc(kClientId, this)), m_refresh(new QTimer(this))
{
    connect(player, &PlayerController::currentChanged, this, &DiscordPresence::update);
    connect(player, &PlayerController::playingChanged, this, &DiscordPresence::update);
    connect(player, &PlayerController::audibleChanged, this, &DiscordPresence::update);
    connect(player, &PlayerController::durationChanged, this, &DiscordPresence::update);
    connect(player, &PlayerController::seeked, this, &DiscordPresence::update);
    connect(player, &PlayerController::displayedArtworkChanged, this, &DiscordPresence::update);
    // Re-derive the timestamps every second, like the old client's heartbeat: they only go out when they
    // moved by more than the noise (buffering stalls), so this costs nothing while playback runs smoothly.
    m_refresh->setInterval(1000);
    connect(m_refresh, &QTimer::timeout, this, &DiscordPresence::update);
    m_refresh->start();
    update();
}

QString DiscordPresence::cleanText(const QString &text)
{
    QByteArray utf8 = text.trimmed().toUtf8();
    if (utf8.size() > 128) {
        utf8.truncate(128);
        while (!utf8.isEmpty() && (quint8(utf8.back()) & 0xC0) == 0x80)
            utf8.chop(1);  // drop a cut multi-byte sequence
        if (!utf8.isEmpty() && (quint8(utf8.back()) & 0x80))
            utf8.chop(1);
    }
    QString out = QString::fromUtf8(utf8).trimmed();
    while (out.size() < 2)
        out.append(QChar(0x2800));  // braille blank: invisible, but counts
    return out;
}

// The status stays in English whatever the app's language: other people read it in their Discord.
void DiscordPresence::update()
{
    DiscordActivity a;
    a.largeImage = kLogo;
    a.largeText = QStringLiteral("SoundCloud Desktop");
    a.smallImage = kIcon;

    if (!m_player->hasTrack() || m_player->restored()) {  // a queue restored from the last session isn't listening
        a.details = QStringLiteral("Exploring SoundCloud");
        a.state = QStringLiteral("Browsing tracks...");
    } else if (!m_player->playing()) {
        a.details = QStringLiteral("Paused");
    } else if (!m_player->audible()) {
        // Loading the stream (a skip, a resume after a long pause) or stalled: the clock in Discord would run
        // ahead of the music, so keep what is shown until sound actually comes out.
        return;
    } else {
        const QVariantMap t = m_player->current();
        a.details = cleanText(t.value(QStringLiteral("title")).toString());
        a.state = cleanText(QStringLiteral("by %1").arg(t.value(QStringLiteral("artist")).toString()));
        const QString cover = m_player->artworkUrl();
        a.largeImage = cover.isEmpty() ? kLogo : cover;
        a.largeText.clear();
        a.start = QDateTime::currentMSecsSinceEpoch() - m_player->precisePosition();
        if (m_player->duration() > 0)
            a.end = a.start + m_player->duration();
        // Discord requires an http(s) URL of at most 512 chars
        const QString url = t.value(QStringLiteral("permalinkUrl")).toString();
        if (url.startsWith(QLatin1StringView("https://")) && url.size() <= 512) {
            a.buttonLabel = QStringLiteral("Listen on SoundCloud");
            a.buttonUrl = url;
        }
    }
    m_ipc->setActivity(a);
}
