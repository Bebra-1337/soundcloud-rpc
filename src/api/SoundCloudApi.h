#pragma once

#include <QHash>
#include <QJSValue>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QUrlQuery>
#include <QVariantMap>
#include <functional>

class QNetworkAccessManager;
class QNetworkReply;
class ClientIdProvider;
class WebSession;

// Client for api-v2.soundcloud.com, the API the website itself runs on, signed in as the user
// (Authorization: OAuth <token>) with the web player's client_id. All calls are async; callbacks are bound to
// a context object and dropped if it is gone (a page popped while its request was in flight).
class SoundCloudApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY readyChanged)
    Q_PROPERTY(QVariantMap me READ me NOTIFY meChanged)
    Q_PROPERTY(int likesRevision READ likesRevision NOTIFY likesChanged)

public:
    using Ok = std::function<void(const QJsonDocument &)>;
    using Fail = std::function<void(int status, const QString &error)>;

    static constexpr auto kUserAgent =
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";

    explicit SoundCloudApi(QObject *parent = nullptr);
    static SoundCloudApi *instance() { return s_instance; }

    QNetworkAccessManager *network() const { return m_nam; }

    void setToken(const QString &token);
    QString token() const { return m_token; }
    bool signedIn() const { return !m_token.isEmpty(); }
    bool ready() const;
    QVariantMap me() const { return m_me; }
    qint64 userId() const { return m_me.value(QStringLiteral("id")).toLongLong(); }

    // path is "/stream" (relative to api-v2) or a full URL (next_href, transcoding URLs)
    void get(const QString &path, const QUrlQuery &query, QObject *context, Ok ok, Fail fail = {});
    void send(const QByteArray &verb, const QString &path, const QJsonObject &body, QObject *context, Ok ok = {},
              Fail fail = {});

    // Full track objects seen in any response, so the player rarely needs to fetch a track again.
    void rememberTrack(const QJsonObject &track);
    QJsonObject cachedTrack(qint64 id) const { return m_tracks.value(id); }
    void forgetTrack(qint64 id) { m_tracks.remove(id); }
    // Fill the cache for these ids (batches of 50 via /tracks?ids=), then call done.
    void fetchTracks(const QList<qint64> &ids, QObject *context, std::function<void()> done);

    // Covers of playlists that have none of their own (their first track's cover, see sc::playlistItem):
    // one /tracks?ids= batch for stubs, a playlist request only when no track ids are known. update(index,
    // item) runs for each resolved item, done() once all are settled.
    void resolveArtwork(const QVariantList &items, QObject *context,
                        std::function<void(int index, const QVariantMap &item)> update, std::function<void()> done = {});

    // QML helpers: callback(result, error)
    Q_INVOKABLE void request(const QString &path, const QVariantMap &query, const QJSValue &callback);
    Q_INVOKABLE void loadHome(const QJSValue &callback);           // [{title, items: [...]}, ...]
    Q_INVOKABLE void loadPlaylist(const QVariant &idOrUrn, const QJSValue &callback);  // {info, items}
    Q_INVOKABLE void loadUser(const QVariant &id, const QJSValue &callback);
    Q_INVOKABLE void resolve(const QString &url, const QJSValue &callback);  // an item map

    int likesRevision() const { return m_likesRevision; }
    Q_INVOKABLE bool isLiked(const QVariant &trackId) const;
    Q_INVOKABLE void setLiked(const QVariant &trackId, bool liked);
    // likes made elsewhere (the phone, the site) only show up after this
    Q_INVOKABLE void refreshLikedIds();

    void fetchMe();

signals:
    void readyChanged();
    void meChanged();
    void likesChanged();
    // a like or unlike from this client (optimistic; emitted again reversed if the server refuses)
    void likeChanged(const QVariantMap &track, bool liked);
    // the token was rejected (expired or revoked): sign in again
    void authRejected(const QString &token);
    void error(const QString &message);

private:
    struct Request {
        QByteArray verb;
        QString path;
        QUrlQuery query;
        QByteArray body;
        QPointer<QObject> context;
        Ok ok;
        Fail fail;
        int attempt = 0;
        bool viaWeb = false;
    };

    void dispatch(Request r);
    void sendViaWeb(Request r, const QUrl &url);
    void onClientId();
    void fetchLikedIds();
    void verifyToken();
    void callback(const QJSValue &cb, const QVariant &result, const QString &error = {});

    static SoundCloudApi *s_instance;
    QNetworkAccessManager *m_nam;
    ClientIdProvider *m_clientId;
    WebSession *m_web;
    bool m_writesViaWeb = false;  // DataDome refused a write: send writes from the browser page
    QString m_token;
    QVariantMap m_me;
    QList<Request> m_waiting;  // queued until a client_id is known
    QHash<qint64, QJsonObject> m_tracks;
    QSet<qint64> m_liked;
    int m_likesRevision = 0;
};
