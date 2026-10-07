#include "player/PlayerController.h"

#include "api/Entities.h"
#include "api/SoundCloudApi.h"

#include <QAudioOutput>
#include <QJsonArray>
#include <QJsonObject>
#include <QMediaPlayer>
#include <QPlaybackOptions>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QSet>
#include <QSettings>
#include <QTimer>
#include <QUrlQuery>
#include <algorithm>
#include <cstring>
#include <dlfcn.h>
#include <link.h>
#include <cmath>
#include <numeric>

// FFmpeg logs every HLS segment it opens (with its signed URL) at info level to stderr. Qt loads FFmpeg as
// libraries of its multimedia plugin, so find the already loaded libavutil and lower its log level to errors
// (QT_FFMPEG_DEBUG keeps the full output).
static void quietFFmpeg()
{
    if (qEnvironmentVariableIsSet("QT_FFMPEG_DEBUG"))
        return;
    dl_iterate_phdr([](dl_phdr_info *info, size_t, void *) -> int {
        if (!info->dlpi_name || !std::strstr(info->dlpi_name, "libavutil.so"))
            return 0;
        if (void *lib = dlopen(info->dlpi_name, RTLD_LAZY | RTLD_NOLOAD)) {
            using SetLevel = void (*)(int);
            if (auto setLevel = reinterpret_cast<SetLevel>(dlsym(lib, "av_log_set_level")))
                setLevel(16);  // AV_LOG_ERROR
            dlclose(lib);
        }
        return 0;
    }, nullptr);
}

// HLS segment URLs are signed and expire; after a long pause the stream is resolved again.
static constexpr qint64 kStaleAfterMs = 10 * 60 * 1000;
static constexpr int kWaveformBars = 120;
// a resolved stream URL is used for the next track only while it is surely still valid
static constexpr qint64 kPrefetchValidMs = 5 * 60 * 1000;

PlayerController::PlayerController(SoundCloudApi *api, QObject *parent)
    : QObject(parent), m_api(api), m_player(new QMediaPlayer(this)), m_output(new QAudioOutput(this))
{
    m_player->setAudioOutput(m_output);
    // FFmpeg probes up to 5 MB by default before it starts, which for HLS means fetching several segments
    // first; SoundCloud's AAC streams carry everything needed in their init segment
    QPlaybackOptions options;
    options.setProbeSize(64 * 1024);
    m_player->setPlaybackOptions(options);
    quietFFmpeg();  // the backend (and FFmpeg with it) is loaded by now
    auto *audibleCheck = new QTimer(this);
    audibleCheck->setInterval(250);
    connect(audibleCheck, &QTimer::timeout, this, &PlayerController::updateAudible);
    audibleCheck->start();
    QSettings s;
    m_output->setVolume(s.value(QStringLiteral("player/volume"), 0.8).toReal());
    m_shuffle = s.value(QStringLiteral("player/shuffle"), false).toBool();
    m_repeat = s.value(QStringLiteral("player/repeat"), int(RepeatOff)).toInt();

    connect(m_player, &QMediaPlayer::positionChanged, this, [this](qint64 p) {
        if (!m_hasSource || m_resumeAt >= 0)
            return;  // a fresh source starts at 0 before the resume seek lands
        // right after a seek the backend can still report positions from before it: ignore those briefly
        if (m_seekClock.isValid() && m_seekClock.elapsed() < 1000 && std::abs(p - m_seekTarget) > 2000)
            return;
        if (p > m_lastReported)
            m_lastAdvance.restart();  // the position moves: sound is coming out
        m_lastReported = p;
        m_position = p;
        m_positionClock.restart();
        emit positionChanged();
        updateAudible();
    });
    connect(m_player, &QMediaPlayer::durationChanged, this, [this](qint64 d) {
        if (d > 0 && d != m_duration) {
            m_duration = d;
            emit durationChanged();
        }
    });
    connect(m_player, &QMediaPlayer::playbackStateChanged, this, [this](QMediaPlayer::PlaybackState state) {
        if (state == QMediaPlayer::PlayingState) {
            m_skips = 0;
            reportPlay();
        }
        emit playingChanged();
        updateAudible();
    });
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this, [this](QMediaPlayer::MediaStatus status) {
        switch (status) {
        case QMediaPlayer::LoadingMedia:
        case QMediaPlayer::StalledMedia:
            setLoading(m_wantPlay);
            break;
        case QMediaPlayer::LoadedMedia:
        case QMediaPlayer::BufferingMedia:
        case QMediaPlayer::BufferedMedia:
            if (m_resumeAt >= 0) {
                const qint64 at = std::exchange(m_resumeAt, -1);
                if (at > 0) {
                    m_player->setPosition(at);
                    m_position = at;
                    m_lastReported = at;
                    m_positionClock.restart();
                    emit positionChanged();
                    emit seeked(at);
                }
            }
            if (status == QMediaPlayer::BufferedMedia)
                setLoading(false);
            break;
        case QMediaPlayer::EndOfMedia:
            if (m_repeat == RepeatOne) {
                m_player->setPosition(0);
                m_player->play();
                emit seeked(0);
            } else {
                advance(+1, false);
            }
            break;
        default:
            break;
        }
        updateAudible();
    });
    connect(m_player, &QMediaPlayer::errorOccurred, this, [this](QMediaPlayer::Error error, const QString &text) {
        if (error == QMediaPlayer::NoError || !m_hasSource)
            return;
        qWarning() << "playback error:" << error << text;
        if (m_retries < 1) {
            // most likely an expired stream URL: resolve it again and continue where it stopped
            ++m_retries;
            resolveAndPlay(m_position, true);
            return;
        }
        m_hasSource = false;
        setLoading(false);
        emit message(QStringLiteral("Playback failed: %1").arg(text));
        if (m_wantPlay) {
            const int gen = m_generation;
            QTimer::singleShot(1500, this, [this, gen] { if (gen == m_generation) advance(+1, false); });
        }
    });
}

bool PlayerController::playing() const
{
    return hasTrack() && m_wantPlay;
}

bool PlayerController::audible() const
{
    // Judged by the position actually advancing rather than by mediaStatus: after a seek the FFmpeg backend
    // does not reliably return to BufferedMedia, which froze the Discord timestamps at the pre-seek time.
    return m_hasSource && m_resumeAt < 0 && m_player->playbackState() == QMediaPlayer::PlayingState
           && m_lastAdvance.isValid() && m_lastAdvance.elapsed() < 1200;
}

void PlayerController::updateAudible()
{
    const bool now = audible();
    if (now == m_audible)
        return;
    m_audible = now;
    // the position doesn't advance while loading or stalled: extrapolate only from the moment sound resumes
    m_positionClock.restart();
    emit audibleChanged();
    if (now)
        prefetchNext();
}

qint64 PlayerController::precisePosition() const
{
    // positionChanged arrives in steps; between them the position is extrapolated while audio is running
    qint64 p = m_position;
    if (m_audible && m_positionClock.isValid())
        p += m_positionClock.elapsed();
    return m_duration > 0 ? std::min(p, m_duration) : p;
}

void PlayerController::setDisplayedArtwork(const QString &url)
{
    if (url == m_displayedArtwork)
        return;
    m_displayedArtwork = url;
    emit displayedArtworkChanged();
}

QString PlayerController::artworkUrl() const
{
    return m_displayedArtwork.isEmpty() ? m_current.value(QStringLiteral("artworkLarge")).toString() : m_displayedArtwork;
}

qreal PlayerController::volume() const
{
    return m_output->volume();
}

void PlayerController::setVolume(qreal v)
{
    v = std::clamp<qreal>(v, 0, 1);
    if (std::abs(v - qreal(m_output->volume())) < 1e-4)
        return;
    m_output->setVolume(v);
    QSettings().setValue(QStringLiteral("player/volume"), v);
    emit volumeChanged();
}

bool PlayerController::muted() const
{
    return m_output->isMuted();
}

void PlayerController::setMuted(bool m)
{
    if (m == m_output->isMuted())
        return;
    m_output->setMuted(m);
    emit volumeChanged();
}

void PlayerController::setShuffle(bool on)
{
    if (on == m_shuffle)
        return;
    m_shuffle = on;
    QSettings().setValue(QStringLiteral("player/shuffle"), on);
    if (!m_queue.isEmpty())
        rebuildOrder(queueIndex());
    emit shuffleChanged();
}

void PlayerController::setRepeatMode(int mode)
{
    mode = std::clamp(mode, 0, 2);
    if (mode == m_repeat)
        return;
    m_repeat = mode;
    QSettings().setValue(QStringLiteral("player/repeat"), mode);
    emit repeatModeChanged();
}

qint64 PlayerController::currentId() const
{
    return m_current.value(QStringLiteral("id")).toLongLong();
}

void PlayerController::rebuildOrder(int current)
{
    const int n = int(m_queue.size());
    m_order.resize(n);
    std::iota(m_order.begin(), m_order.end(), 0);
    if (!m_shuffle) {
        m_pos = current;
        return;
    }
    std::shuffle(m_order.begin(), m_order.end(), *QRandomGenerator::global());
    if (current >= 0) {
        m_order.removeOne(current);
        m_order.prepend(current);
    }
    m_pos = 0;
}

void PlayerController::playList(const QVariantList &items, int index, const QString &context)
{
    QVariantList tracks;
    int start = 0;
    for (int i = 0; i < items.size(); ++i) {
        const QVariantMap m = items.at(i).toMap();
        if (m.value(QStringLiteral("kind")) != QLatin1StringView("track"))
            continue;
        if (i == index)
            start = int(tracks.size());
        tracks.append(m);
    }
    if (tracks.isEmpty())
        return;
    m_queue = tracks;
    m_context = context;
    m_skips = 0;
    rebuildOrder(start);
    emit queueChanged();
    m_wantPlay = true;
    startCurrent();
}

void PlayerController::playTrack(const QVariantMap &item)
{
    playList({item}, 0, {});
}

void PlayerController::playNext(const QVariantMap &item)
{
    if (m_queue.isEmpty()) {
        playTrack(item);
        return;
    }
    m_queue.append(item);
    m_order.insert(m_pos + 1, int(m_queue.size() - 1));
    emit queueChanged();
}

void PlayerController::enqueue(const QVariantMap &item)
{
    if (m_queue.isEmpty()) {
        playTrack(item);
        return;
    }
    m_queue.append(item);
    m_order.append(int(m_queue.size() - 1));
    emit queueChanged();
}

void PlayerController::jumpTo(int index)
{
    const int p = int(m_order.indexOf(index));
    if (p < 0)
        return;
    m_pos = p;
    m_wantPlay = true;
    startCurrent();
}

void PlayerController::setLoading(bool on)
{
    if (on == m_loading)
        return;
    m_loading = on;
    emit loadingChanged();
}

void PlayerController::startCurrent()
{
    ++m_generation;
    m_retries = 0;
    m_reported = false;
    m_resumeAt = -1;
    m_hasSource = false;
    m_player->stop();
    m_player->setSource({});
    updateAudible();

    m_current = m_queue.value(queueIndex()).toMap();
    m_position = 0;
    m_positionClock.restart();
    m_lastReported = 0;
    m_lastAdvance.invalidate();
    m_duration = m_current.value(QStringLiteral("durationMs")).toLongLong();
    m_waveform.clear();
    emit currentChanged();
    emit positionChanged();
    emit durationChanged();
    emit waveformChanged();
    emit playingChanged();
    setLoading(true);
    resolveAndPlay(-1, false);
}

void PlayerController::withTrack(qint64 id, bool fresh, std::function<void(const QJsonObject &)> cb)
{
    if (fresh)
        m_api->forgetTrack(id);
    const QJsonObject cached = m_api->cachedTrack(id);
    if (!cached.isEmpty()) {
        cb(cached);
        return;
    }
    m_api->get(QStringLiteral("/tracks/%1").arg(id), {}, this,
               [cb](const QJsonDocument &doc) { cb(doc.object()); },
               [cb](int, const QString &) { cb({}); });
}

void PlayerController::resolveAndPlay(qint64 resumeAt, bool fresh)
{
    const int gen = m_generation;
    const qint64 id = currentId();
    if (!id)
        return;
    setLoading(m_wantPlay);
    withTrack(id, fresh, [this, gen, resumeAt, fresh](const QJsonObject &t) {
        if (gen != m_generation)
            return;
        if (t.isEmpty()) {
            setLoading(false);
            emit message(QStringLiteral("Could not load “%1”").arg(m_current.value(QStringLiteral("title")).toString()));
            return;
        }
        QVariantMap full = sc::trackItem(t);
        if (m_current.contains(QStringLiteral("repostedBy")))
            full[QStringLiteral("repostedBy")] = m_current.value(QStringLiteral("repostedBy"));
        m_current = full;
        if (queueIndex() >= 0)
            m_queue[queueIndex()] = full;
        emit currentChanged();
        const qint64 d = full.value(QStringLiteral("durationMs")).toLongLong();
        if (d > 0 && m_duration <= 0) {
            m_duration = d;
            emit durationChanged();
        }
        if (m_waveform.isEmpty())
            fetchWaveform(full.value(QStringLiteral("waveformUrl")).toString());

        const QJsonObject tc = sc::pickTranscoding(t);
        if (tc.isEmpty()) {
            skipUnplayable(full.value(QStringLiteral("title")).toString());
            return;
        }
        auto start = [this, gen, resumeAt](const QString &url) {
            if (gen != m_generation)
                return;
            if (url.isEmpty()) {
                setLoading(false);
                emit message(QStringLiteral("SoundCloud returned no stream for this track"));
                return;
            }
            // setSource() stops the old source first, and that stop reports LoadedMedia, which would spend
            // m_resumeAt on the old source (the new one then started at 0 after a long pause or an error)
            m_hasSource = false;
            m_player->setSource({});
            m_resumeAt = resumeAt;
            m_hasSource = true;
            m_player->setSource(QUrl(url));
            if (m_wantPlay)
                m_player->play();
            else
                setLoading(false);
        };
        // resolved ahead while the previous track played: saves the round trip on a skip
        if (!fresh && m_prefetch.id == t.value(QLatin1StringView("id")).toInteger() && m_prefetch.age.isValid()
            && m_prefetch.age.elapsed() < kPrefetchValidMs) {
            const QString url = std::exchange(m_prefetch.url, {});
            m_prefetch.id = 0;
            start(url);
            return;
        }
        m_api->get(tc.value(QLatin1StringView("url")).toString(), streamQuery(t), this,
            [start](const QJsonDocument &doc) { start(doc.object().value(QLatin1StringView("url")).toString()); },
            [this, gen, resumeAt, fresh](int status, const QString &err) {
                if (gen != m_generation)
                    return;
                if (!fresh && (status == 401 || status == 403 || status == 404)) {
                    resolveAndPlay(resumeAt, true);  // stale track_authorization: fetch the track again
                    return;
                }
                setLoading(false);
                emit message(QStringLiteral("Could not load the stream (%1)").arg(err));
                if (m_wantPlay)
                    QTimer::singleShot(1500, this, [this, gen] { if (gen == m_generation) advance(+1, false); });
            });
    });
}

QUrlQuery PlayerController::streamQuery(const QJsonObject &track)
{
    QUrlQuery q;
    const QString auth = track.value(QLatin1StringView("track_authorization")).toString();
    if (!auth.isEmpty())
        q.addQueryItem(QStringLiteral("track_authorization"), auth);
    return q;
}

void PlayerController::prefetchNext()
{
    if (m_repeat == RepeatOne || m_pos + 1 >= m_order.size())
        return;
    const qint64 id = m_queue.value(m_order.at(m_pos + 1)).toMap().value(QStringLiteral("id")).toLongLong();
    if (!id || (m_prefetch.id == id && m_prefetch.age.isValid() && m_prefetch.age.elapsed() < kPrefetchValidMs))
        return;
    withTrack(id, false, [this, id](const QJsonObject &t) {
        const QJsonObject tc = sc::pickTranscoding(t);
        if (tc.isEmpty())
            return;
        m_api->get(tc.value(QLatin1StringView("url")).toString(), streamQuery(t), this, [this, id](const QJsonDocument &doc) {
            const QString url = doc.object().value(QLatin1StringView("url")).toString();
            if (url.isEmpty())
                return;
            m_prefetch.id = id;
            m_prefetch.url = url;
            m_prefetch.age.start();
        });
    });
}

void PlayerController::skipUnplayable(const QString &title)
{
    setLoading(false);
    m_hasSource = false;
    emit message(QStringLiteral("“%1” can only be played on soundcloud.com").arg(title));
    if (++m_skips < m_queue.size()) {
        const int gen = m_generation;
        QTimer::singleShot(700, this, [this, gen] { if (gen == m_generation) advance(+1, false); });
    } else {
        m_wantPlay = false;
        emit playingChanged();
    }
}

void PlayerController::advance(int dir, bool userAction)
{
    if (m_order.isEmpty())
        return;
    int np = m_pos + dir;
    if (np >= m_order.size()) {
        if (m_repeat == RepeatAll) {
            np = 0;
        } else {
            autoplayRelated();
            return;
        }
    } else if (np < 0) {
        if (m_repeat == RepeatAll) {
            np = int(m_order.size() - 1);
        } else {
            seek(0);
            return;
        }
    }
    Q_UNUSED(userAction)
    m_pos = np;
    m_wantPlay = true;
    startCurrent();
}

void PlayerController::autoplayRelated()
{
    const qint64 id = currentId();
    const int gen = m_generation;
    auto stop = [this] {
        m_wantPlay = false;
        setLoading(false);
        emit playingChanged();
    };
    if (!id) {
        stop();
        return;
    }
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("limit"), QStringLiteral("20"));
    m_api->get(QStringLiteral("/tracks/%1/related").arg(id), q, this, [this, gen, stop](const QJsonDocument &doc) {
        if (gen != m_generation)
            return;
        QSet<qint64> known;
        for (const QVariant &v : std::as_const(m_queue))
            known.insert(v.toMap().value(QStringLiteral("id")).toLongLong());
        int added = 0;
        for (const QJsonValue &v : doc.object().value(QLatin1StringView("collection")).toArray()) {
            const QVariantMap m = sc::item(v.toObject());
            if (m.value(QStringLiteral("kind")) != QLatin1StringView("track") || !m.value(QStringLiteral("playable")).toBool()
                || known.contains(m.value(QStringLiteral("id")).toLongLong()))
                continue;
            m_queue.append(m);
            m_order.append(int(m_queue.size() - 1));
            ++added;
        }
        if (!added) {
            stop();
            return;
        }
        if (m_context.isEmpty() || !m_context.endsWith(QLatin1StringView("+ related")))
            m_context = m_context.isEmpty() ? QStringLiteral("Related tracks") : m_context + QStringLiteral(" + related");
        emit queueChanged();
        ++m_pos;
        m_wantPlay = true;
        startCurrent();
    }, [this, gen, stop](int, const QString &) {
        if (gen == m_generation)
            stop();
    });
}

void PlayerController::togglePlay()
{
    if (playing())
        pause();
    else
        play();
}

void PlayerController::play()
{
    if (!hasTrack())
        return;
    m_wantPlay = true;
    emit playingChanged();
    if (!m_hasSource) {
        resolveAndPlay(m_position > 0 ? m_position : -1, false);
    } else if (m_pausedFor.isValid() && m_pausedFor.elapsed() > kStaleAfterMs) {
        m_pausedFor.invalidate();
        resolveAndPlay(m_position, true);
    } else {
        m_player->play();
    }
}

void PlayerController::pause()
{
    m_wantPlay = false;
    m_player->pause();
    m_pausedFor.start();
    setLoading(false);
    emit playingChanged();
}

void PlayerController::next()
{
    advance(+1, true);
}

void PlayerController::previous()
{
    if (m_position > 3000)
        seek(0);
    else
        advance(-1, true);
}

void PlayerController::seek(qint64 ms)
{
    if (!hasTrack())
        return;
    ms = std::clamp<qint64>(ms, 0, std::max<qint64>(0, m_duration - 500));
    m_position = ms;
    m_positionClock.restart();
    m_seekTarget = ms;
    m_seekClock.start();
    m_lastReported = ms;  // a backward seek must not look like the position standing still
    if (m_hasSource && m_resumeAt < 0)
        m_player->setPosition(ms);
    else
        m_resumeAt = ms;
    emit positionChanged();
    emit seeked(ms);
}

void PlayerController::reportPlay()
{
    if (m_reported || !m_api->ready())
        return;
    m_reported = true;
    // keeps "Recently played" and the site's recommendations in step with what is played here
    const QString urn = m_current.value(QStringLiteral("urn")).toString();
    m_api->send("POST", QStringLiteral("/me/play-history"), {{QStringLiteral("track_urn"), urn}}, this);
}

void PlayerController::fetchWaveform(const QString &url)
{
    if (url.isEmpty())
        return;
    QString jsonUrl = url;
    // older tracks point at a PNG on wave.sndcdn.com; the same samples are served as JSON by wis.sndcdn.com
    if (jsonUrl.endsWith(QLatin1StringView(".png"))) {
        jsonUrl = QStringLiteral("https://wis.sndcdn.com/") + QUrl(url).fileName();
        jsonUrl.replace(QLatin1StringView(".png"), QLatin1StringView(".json"));
    }
    const int gen = m_generation;
    QNetworkReply *reply = m_api->network()->get(QNetworkRequest(QUrl(jsonUrl)));
    connect(reply, &QNetworkReply::finished, this, [this, reply, gen] {
        reply->deleteLater();
        if (gen != m_generation)
            return;
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonArray samples = o.value(QLatin1StringView("samples")).toArray();
        if (samples.isEmpty())
            return;
        QList<double> bars(kWaveformBars, 0.0);
        double peak = 0;
        for (int i = 0; i < samples.size(); ++i) {
            const int b = int(qint64(i) * kWaveformBars / samples.size());
            bars[b] = std::max(bars[b], samples.at(i).toDouble());
            peak = std::max(peak, bars[b]);
        }
        m_waveform.clear();
        for (double v : std::as_const(bars))
            m_waveform.append(peak > 0 ? v / peak : 0.0);
        emit waveformChanged();
    });
}
