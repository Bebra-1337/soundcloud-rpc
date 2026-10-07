#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QStringList>
#include <QVariantMap>

class PlayerController;
class Application;

// MPRIS (org.mpris.MediaPlayer2.soundcloud_rpc) so desktop media widgets, playerctl and media keys see and
// control the player.
class Mpris : public QObject
{
    Q_OBJECT
public:
    Mpris(PlayerController *player, Application *app, QObject *parent = nullptr);

    PlayerController *player() const { return m_player; }
    Application *app() const { return m_app; }
    QVariantMap metadata() const { return m_metadata; }
    QString playbackStatus() const;

private:
    void onCurrentChanged();
    void propertiesChanged(const QVariantMap &changed);

    PlayerController *m_player;
    Application *m_app;
    QVariantMap m_metadata;
    QString m_lastStatus;
    class MprisPlayerAdaptor *m_playerAdaptor;
};

class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes)

public:
    explicit MprisRootAdaptor(Mpris *parent);
    bool canQuit() const { return true; }
    bool canRaise() const { return true; }
    bool hasTrackList() const { return false; }
    QString identity() const { return QStringLiteral("SoundCloud Desktop"); }
    QString desktopEntry() const { return QStringLiteral("soundcloud-rpc"); }
    QStringList supportedUriSchemes() const { return {QStringLiteral("https")}; }
    QStringList supportedMimeTypes() const { return {}; }

public slots:
    void Raise();
    void Quit();

private:
    Mpris *m_mpris;
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QString LoopStatus READ loopStatus WRITE setLoopStatus)
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(bool Shuffle READ shuffle WRITE setShuffle)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ rate)
    Q_PROPERTY(double MaximumRate READ rate)
    Q_PROPERTY(bool CanGoNext READ canControl)
    Q_PROPERTY(bool CanGoPrevious READ canControl)
    Q_PROPERTY(bool CanPlay READ canControl)
    Q_PROPERTY(bool CanPause READ canControl)
    Q_PROPERTY(bool CanSeek READ canControl)
    Q_PROPERTY(bool CanControl READ alwaysTrue)

public:
    explicit MprisPlayerAdaptor(Mpris *parent);
    QString playbackStatus() const;
    QString loopStatus() const;
    void setLoopStatus(const QString &status);
    double rate() const { return 1.0; }
    void setRate(double) {}
    bool shuffle() const;
    void setShuffle(bool on);
    QVariantMap metadata() const;
    double volume() const;
    void setVolume(double v);
    qlonglong position() const;
    bool canControl() const;
    bool alwaysTrue() const { return true; }

public slots:
    void Next();
    void Previous();
    void Pause();
    void PlayPause();
    void Stop();
    void Play();
    void Seek(qlonglong Offset);
    void SetPosition(const QDBusObjectPath &TrackId, qlonglong Position);
    void OpenUri(const QString &Uri);

signals:
    void Seeked(qlonglong Position);

private:
    Mpris *m_mpris;
};
