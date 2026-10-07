#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QUrlQuery>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class QMediaPlayer;
class QAudioOutput;
class QTimer;
class QJsonObject;
class SoundCloudApi;

// The player: a queue of track items (see sc::item), streams resolved through api-v2 and played by
// QMediaPlayer (FFmpeg backend, HLS). Owns shuffle/repeat, skips tracks that can't be played here (DRM-only),
// re-resolves expired stream URLs, and falls back to related tracks when the queue runs out.
class PlayerController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap current READ current NOTIFY currentChanged)
    Q_PROPERTY(bool hasTrack READ hasTrack NOTIFY currentChanged)
    Q_PROPERTY(int queueIndex READ queueIndex NOTIFY currentChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY volumeChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(QVariantList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(QString contextTitle READ contextTitle NOTIFY queueChanged)
    Q_PROPERTY(QVariantList waveform READ waveform NOTIFY waveformChanged)
    // the cover URL the UI actually managed to load (the artwork can 404 and fall back to the avatar)
    Q_PROPERTY(QString displayedArtwork READ displayedArtwork WRITE setDisplayedArtwork NOTIFY displayedArtworkChanged)

public:
    enum Repeat { RepeatOff = 0, RepeatAll = 1, RepeatOne = 2 };
    Q_ENUM(Repeat)

    explicit PlayerController(SoundCloudApi *api, QObject *parent = nullptr);
    ~PlayerController() override;

    QMediaPlayer *mediaPlayer() const { return m_player; }

    QVariantMap current() const { return m_current; }
    bool hasTrack() const { return !m_current.isEmpty(); }
    int queueIndex() const { return m_pos >= 0 && m_pos < m_order.size() ? m_order.at(m_pos) : -1; }
    bool playing() const;
    bool loading() const { return m_loading; }
    qint64 position() const { return m_position; }
    qint64 duration() const { return m_duration; }
    qreal volume() const;
    void setVolume(qreal v);
    bool muted() const;
    void setMuted(bool m);
    bool shuffle() const { return m_shuffle; }
    void setShuffle(bool on);
    int repeatMode() const { return m_repeat; }
    void setRepeatMode(int mode);
    QVariantList queue() const { return m_queue; }
    QString contextTitle() const { return m_context; }
    QVariantList waveform() const { return m_waveform; }
    bool canGoNext() const { return hasTrack(); }
    // sound is actually coming out: playing and the position advancing (Discord timestamps start from here)
    bool audible() const;
    // position in ms right now, extrapolated between the backend's position reports
    qint64 precisePosition() const;
    QString displayedArtwork() const { return m_displayedArtwork; }
    void setDisplayedArtwork(const QString &url);
    // cover for Discord / MPRIS: the one the UI shows, else the track's artwork URL
    QString artworkUrl() const;
    bool canGoPrevious() const { return hasTrack(); }

    // The queue and the position survive a restart (session.json in the app's data directory): restored paused,
    // and nothing is resolved until play. restored() stays true until something is played in this session.
    void restoreSession();
    void saveSession() const;
    void clearSession();  // sign-out: stop, empty the queue, delete the file
    bool restored() const { return m_restored; }

    // start playing items[index]; non-track items are left out of the queue
    Q_INVOKABLE void playList(const QVariantList &items, int index, const QString &context = {});
    Q_INVOKABLE void playTrack(const QVariantMap &item);
    Q_INVOKABLE void playNext(const QVariantMap &item);
    Q_INVOKABLE void enqueue(const QVariantMap &item);
    Q_INVOKABLE void jumpTo(int queueIndex);
    Q_INVOKABLE void togglePlay();
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE void cycleRepeat() { setRepeatMode((m_repeat + 1) % 3); }

signals:
    void currentChanged();
    void playingChanged();
    void loadingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void shuffleChanged();
    void repeatModeChanged();
    void queueChanged();
    void waveformChanged();
    void seeked(qint64 ms);
    void audibleChanged();
    void displayedArtworkChanged();
    void message(const QString &text);

private:
    void rebuildOrder(int current);
    void startCurrent();
    void resolveAndPlay(qint64 resumeAt, bool freshTrack);
    void withTrack(qint64 id, bool fresh, std::function<void(const QJsonObject &)> cb);
    void skipUnplayable(const QString &title);
    void advance(int dir, bool userAction);
    void autoplayRelated();
    void fetchWaveform(const QString &url);
    void setLoading(bool on);
    void prefetchNext();
    static QUrlQuery streamQuery(const QJsonObject &track);
    void updateAudible();
    void reportPlay();
    qint64 currentId() const;

    SoundCloudApi *m_api;
    QMediaPlayer *m_player;
    QAudioOutput *m_output;

    QVariantList m_queue;
    QList<int> m_order;  // play order over m_queue (identity, or shuffled with the current track first)
    int m_pos = -1;      // index into m_order
    QString m_context;
    QVariantMap m_current;
    QVariantList m_waveform;

    bool m_wantPlay = false;
    bool m_loading = false;
    bool m_shuffle = false;
    int m_repeat = RepeatOff;
    qint64 m_position = 0;
    qint64 m_duration = 0;
    qint64 m_resumeAt = -1;
    int m_generation = 0;
    int m_retries = 0;
    int m_skips = 0;
    bool m_reported = false;
    bool m_hasSource = false;
    bool m_restored = false;
    QTimer *m_sessionSave = nullptr;
    QElapsedTimer m_pausedFor;
    QElapsedTimer m_positionClock;
    QElapsedTimer m_seekClock;
    QElapsedTimer m_lastAdvance;  // last position report that moved forward
    qint64 m_lastReported = 0;
    qint64 m_seekTarget = 0;
    bool m_audible = false;
    QString m_displayedArtwork;
    struct {
        qint64 id = 0;
        QString url;
        QElapsedTimer age;
    } m_prefetch;  // the next track's stream URL, resolved while the current one plays
};
