#include "integrations/Mpris.h"

#include "app/Application.h"
#include "player/PlayerController.h"

#include <QDBusConnection>
#include <QDBusMessage>

static const QString kService = QStringLiteral("org.mpris.MediaPlayer2.soundcloud_rpc");
static const QString kPath = QStringLiteral("/org/mpris/MediaPlayer2");
static const QString kPlayerIface = QStringLiteral("org.mpris.MediaPlayer2.Player");
static const QString kNoTrack = QStringLiteral("/org/mpris/MediaPlayer2/TrackList/NoTrack");

Mpris::Mpris(PlayerController *player, Application *app, QObject *parent)
    : QObject(parent), m_player(player), m_app(app)
{
    new MprisRootAdaptor(this);
    m_playerAdaptor = new MprisPlayerAdaptor(this);
    m_metadata = {{QStringLiteral("mpris:trackid"), QVariant::fromValue(QDBusObjectPath(kNoTrack))}};
    m_lastStatus = playbackStatus();

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(kService))
        qWarning() << "Failed to register D-Bus service" << kService;
    if (!bus.registerObject(kPath, this))
        qWarning() << "Failed to register D-Bus object" << kPath;

    connect(player, &PlayerController::currentChanged, this, &Mpris::onCurrentChanged);
    connect(player, &PlayerController::durationChanged, this, &Mpris::onCurrentChanged);
    connect(player, &PlayerController::displayedArtworkChanged, this, &Mpris::onCurrentChanged);
    connect(player, &PlayerController::playingChanged, this, [this] {
        const QString status = playbackStatus();
        if (status != m_lastStatus) {
            m_lastStatus = status;
            propertiesChanged({{QStringLiteral("PlaybackStatus"), status}});
        }
    });
    connect(player, &PlayerController::volumeChanged, this, [this] {
        propertiesChanged({{QStringLiteral("Volume"), m_player->volume()}});
    });
    connect(player, &PlayerController::shuffleChanged, this, [this] {
        propertiesChanged({{QStringLiteral("Shuffle"), m_player->shuffle()}});
    });
    connect(player, &PlayerController::repeatModeChanged, this, [this] {
        propertiesChanged({{QStringLiteral("LoopStatus"), m_playerAdaptor->loopStatus()}});
    });
    connect(player, &PlayerController::seeked, this, [this](qint64 ms) { emit m_playerAdaptor->Seeked(ms * 1000); });
}

QString Mpris::playbackStatus() const
{
    if (!m_player->hasTrack())
        return QStringLiteral("Stopped");
    return m_player->playing() ? QStringLiteral("Playing") : QStringLiteral("Paused");
}

void Mpris::onCurrentChanged()
{
    QVariantMap md;
    if (!m_player->hasTrack()) {
        md[QStringLiteral("mpris:trackid")] = QVariant::fromValue(QDBusObjectPath(kNoTrack));
    } else {
        const QVariantMap t = m_player->current();
        md[QStringLiteral("mpris:trackid")] = QVariant::fromValue(
            QDBusObjectPath(QStringLiteral("/org/soundcloud_rpc/track/%1").arg(t.value(QStringLiteral("id")).toLongLong())));
        md[QStringLiteral("xesam:title")] = t.value(QStringLiteral("title")).toString();
        md[QStringLiteral("xesam:artist")] = QStringList{t.value(QStringLiteral("artist")).toString()};
        if (m_player->duration() > 0)
            md[QStringLiteral("mpris:length")] = qlonglong(m_player->duration() * 1000);
        const QString art = m_player->artworkUrl();
        if (!art.isEmpty())
            md[QStringLiteral("mpris:artUrl")] = art;
        const QString url = t.value(QStringLiteral("permalinkUrl")).toString();
        if (!url.isEmpty())
            md[QStringLiteral("xesam:url")] = url;
        const QString genre = t.value(QStringLiteral("genre")).toString();
        if (!genre.isEmpty())
            md[QStringLiteral("xesam:genre")] = QStringList{genre};
    }
    QVariantMap changed;
    if (md != m_metadata) {
        m_metadata = md;
        changed[QStringLiteral("Metadata")] = md;
    }
    const QString status = playbackStatus();
    if (status != m_lastStatus) {
        m_lastStatus = status;
        changed[QStringLiteral("PlaybackStatus")] = status;
    }
    if (!changed.isEmpty())
        propertiesChanged(changed);
}

// Status bars only refresh on PropertiesChanged.
void Mpris::propertiesChanged(const QVariantMap &changed)
{
    QDBusMessage msg = QDBusMessage::createSignal(kPath, QStringLiteral("org.freedesktop.DBus.Properties"),
                                                  QStringLiteral("PropertiesChanged"));
    msg << kPlayerIface << changed << QStringList();
    QDBusConnection::sessionBus().send(msg);
}

MprisRootAdaptor::MprisRootAdaptor(Mpris *parent) : QDBusAbstractAdaptor(parent), m_mpris(parent) {}

void MprisRootAdaptor::Raise()
{
    m_mpris->app()->raiseWindow();
}

void MprisRootAdaptor::Quit()
{
    m_mpris->app()->quit();
}

MprisPlayerAdaptor::MprisPlayerAdaptor(Mpris *parent) : QDBusAbstractAdaptor(parent), m_mpris(parent) {}

QString MprisPlayerAdaptor::playbackStatus() const
{
    return m_mpris->playbackStatus();
}

QString MprisPlayerAdaptor::loopStatus() const
{
    switch (m_mpris->player()->repeatMode()) {
    case PlayerController::RepeatAll:
        return QStringLiteral("Playlist");
    case PlayerController::RepeatOne:
        return QStringLiteral("Track");
    default:
        return QStringLiteral("None");
    }
}

void MprisPlayerAdaptor::setLoopStatus(const QString &status)
{
    if (status == QLatin1StringView("Playlist"))
        m_mpris->player()->setRepeatMode(PlayerController::RepeatAll);
    else if (status == QLatin1StringView("Track"))
        m_mpris->player()->setRepeatMode(PlayerController::RepeatOne);
    else
        m_mpris->player()->setRepeatMode(PlayerController::RepeatOff);
}

bool MprisPlayerAdaptor::shuffle() const
{
    return m_mpris->player()->shuffle();
}

void MprisPlayerAdaptor::setShuffle(bool on)
{
    m_mpris->player()->setShuffle(on);
}

QVariantMap MprisPlayerAdaptor::metadata() const
{
    return m_mpris->metadata();
}

double MprisPlayerAdaptor::volume() const
{
    return m_mpris->player()->volume();
}

void MprisPlayerAdaptor::setVolume(double v)
{
    m_mpris->player()->setVolume(v);
}

qlonglong MprisPlayerAdaptor::position() const
{
    return m_mpris->player()->precisePosition() * 1000;
}

bool MprisPlayerAdaptor::canControl() const
{
    return true;
}

void MprisPlayerAdaptor::Next() { m_mpris->player()->next(); }
void MprisPlayerAdaptor::Previous() { m_mpris->player()->previous(); }
void MprisPlayerAdaptor::Pause() { m_mpris->player()->pause(); }
void MprisPlayerAdaptor::PlayPause() { m_mpris->player()->togglePlay(); }
void MprisPlayerAdaptor::Stop() { m_mpris->player()->pause(); }
void MprisPlayerAdaptor::Play() { m_mpris->player()->play(); }

void MprisPlayerAdaptor::Seek(qlonglong offset)
{
    PlayerController *p = m_mpris->player();
    p->seek(p->precisePosition() + offset / 1000);
}

void MprisPlayerAdaptor::SetPosition(const QDBusObjectPath &trackId, qlonglong position)
{
    // ignored when it refers to a track that is no longer current (spec)
    if (trackId.path() != m_mpris->metadata().value(QStringLiteral("mpris:trackid")).value<QDBusObjectPath>().path())
        return;
    m_mpris->player()->seek(position / 1000);
}

void MprisPlayerAdaptor::OpenUri(const QString &uri)
{
    m_mpris->app()->openSoundCloudUrl(uri);
}
