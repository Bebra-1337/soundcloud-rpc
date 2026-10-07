#include "api/SoundCloudApi.h"

#include "api/ClientIdProvider.h"
#include "api/Entities.h"
#include "api/WebSession.h"

#include <QElapsedTimer>
#include <QJSEngine>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <memory>

SoundCloudApi *SoundCloudApi::s_instance = nullptr;

static const QString kApiBase = QStringLiteral("https://api-v2.soundcloud.com");

SoundCloudApi::SoundCloudApi(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this))
{
    s_instance = this;
    m_nam->setTransferTimeout(20000);
    m_clientId = new ClientIdProvider(m_nam, kUserAgent, this);
    m_web = new WebSession(this);
    connect(m_clientId, &ClientIdProvider::ready, this, &SoundCloudApi::onClientId);
    connect(m_clientId, &ClientIdProvider::failed, this, [this](const QString &err) {
        // fail everything that waited for an id; a later request triggers a new attempt
        const auto waiting = std::exchange(m_waiting, {});
        for (const Request &r : waiting) {
            if (r.context && r.fail)
                r.fail(0, err);
        }
        emit error(QStringLiteral("Could not reach soundcloud.com: %1").arg(err));
    });
}

bool SoundCloudApi::ready() const
{
    return signedIn() && !m_me.isEmpty();
}

void SoundCloudApi::setToken(const QString &token)
{
    if (token == m_token)
        return;
    m_token = token;
    m_web->setToken(token);
    m_me.clear();
    m_liked.clear();
    emit meChanged();
    emit readyChanged();
    if (!m_token.isEmpty())
        fetchMe();
}

void SoundCloudApi::fetchMe()
{
    get(QStringLiteral("/me"), {}, this, [this](const QJsonDocument &doc) {
        const QJsonObject o = doc.object();
        QVariantMap me = sc::userItem(o);
        me[QStringLiteral("username")] = o.value(QLatin1StringView("username")).toString();
        m_me = me;
        emit meChanged();
        emit readyChanged();
        fetchLikedIds();
    }, [this](int status, const QString &) {
        if (status != 401 && status != 403)  // offline: try again later; 401 is handled by authRejected
            QTimer::singleShot(10000, this, [this] { if (signedIn() && m_me.isEmpty()) fetchMe(); });
    });
}

void SoundCloudApi::verifyToken()
{
    static QElapsedTimer lastCheck;
    if (lastCheck.isValid() && lastCheck.elapsed() < 30000)
        return;
    lastCheck.start();
    get(QStringLiteral("/me"), {}, this, {});  // a 401 there emits authRejected
}

void SoundCloudApi::get(const QString &path, const QUrlQuery &query, QObject *context, Ok ok, Fail fail)
{
    dispatch({"GET", path, query, {}, context, std::move(ok), std::move(fail)});
}

void SoundCloudApi::send(const QByteArray &verb, const QString &path, const QJsonObject &body, QObject *context,
                         Ok ok, Fail fail)
{
    const QByteArray data = body.isEmpty() ? QByteArray() : QJsonDocument(body).toJson(QJsonDocument::Compact);
    dispatch({verb, path, {}, data, context, std::move(ok), std::move(fail)});
}

void SoundCloudApi::onClientId()
{
    const auto waiting = std::exchange(m_waiting, {});
    for (const Request &r : waiting)
        dispatch(r);
}

// Cache every full track object found anywhere in a response.
static void harvest(SoundCloudApi *api, const QJsonValue &v, int depth = 0)
{
    if (depth > 6)
        return;
    if (v.isArray()) {
        for (const QJsonValue &e : v.toArray())
            harvest(api, e, depth + 1);
    } else if (v.isObject()) {
        const QJsonObject o = v.toObject();
        if (o.value(QLatin1StringView("kind")).toString() == QLatin1StringView("track")) {
            api->rememberTrack(o);
            return;
        }
        for (auto it = o.begin(); it != o.end(); ++it) {
            if (it.value().isObject() || it.value().isArray())
                harvest(api, it.value(), depth + 1);
        }
    }
}

void SoundCloudApi::dispatch(Request r)
{
    if (m_clientId->clientId().isEmpty() || m_clientId->refreshing()) {
        m_waiting.append(r);
        m_clientId->refresh();
        return;
    }

    QUrl url(r.path.startsWith(QLatin1StringView("http")) ? r.path : kApiBase + r.path);
    QUrlQuery q(url);
    q.removeAllQueryItems(QStringLiteral("client_id"));
    for (const auto &[k, v] : r.query.queryItems(QUrl::FullyDecoded))
        q.addQueryItem(k, v);
    q.addQueryItem(QStringLiteral("client_id"), m_clientId->clientId());
    url.setQuery(q);

    if (r.verb != "GET" && m_writesViaWeb) {
        sendViaWeb(r, url);
        return;
    }

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray(kUserAgent));
    req.setRawHeader("Accept", "application/json, text/javascript, */*; q=0.01");
    req.setRawHeader("Origin", "https://soundcloud.com");
    req.setRawHeader("Referer", "https://soundcloud.com/");
    if (!m_token.isEmpty())
        req.setRawHeader("Authorization", "OAuth " + m_token.toUtf8());
    if (!r.body.isEmpty())
        req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));

    QNetworkReply *reply = r.verb == "GET" ? m_nam->get(req) : m_nam->sendCustomRequest(req, r.verb, r.body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, r]() mutable {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();

        // DataDome (the anti-bot layer in front of the API) refuses some requests from a plain HTTP client,
        // likes among them: send it again from a soundcloud.com page in the user's browser profile, like the
        // site does, and route later writes there directly.
        if (status == 403 && reply->hasRawHeader("x-datadome") && !r.viaWeb) {
            if (r.verb != "GET")
                m_writesViaWeb = true;
            sendViaWeb(r, reply->url());
            return;
        }

        if ((status == 401 || status == 403) && r.attempt == 0) {
            // A rotated client_id shows up as 401/403 on everything: fetch it again (at most once a minute)
            // and retry this request once.
            static QElapsedTimer lastRefresh;
            r.attempt = 1;
            if (!lastRefresh.isValid() || lastRefresh.elapsed() > 60000) {
                lastRefresh.start();
                m_waiting.append(r);
                m_clientId->refresh();
            } else {
                dispatch(r);
            }
            return;
        }
        // still 401 with a fresh client_id: check whether the token itself was rejected. Only /me decides, so
        // one endpoint refusing (or a stream URL, which carries its own track authorization) can't sign out.
        if (status == 401 && !m_token.isEmpty() && reply->url().host() == QLatin1StringView("api-v2.soundcloud.com")) {
            if (reply->url().path() == QLatin1StringView("/me"))
                emit authRejected(m_token);
            else if (!reply->url().path().startsWith(QLatin1StringView("/media/")))
                verifyToken();
        }
        if (!r.context)
            return;
        if (status < 200 || status >= 300) {
            const QString err = status ? QStringLiteral("HTTP %1").arg(status) : reply->errorString();
            qWarning().noquote() << "api" << r.verb << reply->url().path() << "failed:" << err;
            if (status >= 400 && status != 404) {
                // what refused it: an API error message, or the anti-bot layer (DataDome) in front of the API
                for (const auto &[name, value] : reply->rawHeaderPairs()) {
                    const QByteArray lower = name.toLower();
                    if (lower.contains("datadome") || lower.startsWith("x-dd") || lower == "server" || lower == "content-type")
                        qWarning().noquote() << "    " << name << ":" << value.left(200);
                }
                if (!data.isEmpty())
                    qWarning().noquote() << "    body:" << QString::fromUtf8(data.left(400)).simplified();
            }
            if (r.fail)
                r.fail(status, err);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(data);
        harvest(this, doc.isArray() ? QJsonValue(doc.array()) : QJsonValue(doc.object()));
        if (r.ok)
            r.ok(doc);
    });
}

void SoundCloudApi::sendViaWeb(Request r, const QUrl &url)
{
    r.viaWeb = true;
    m_web->send(r.verb, url, r.body, r.context, [r, url](int status, const QByteArray &body) {
        if (!r.context)
            return;
        if (status >= 200 && status < 300) {
            if (r.ok)
                r.ok(QJsonDocument::fromJson(body));
            return;
        }
        const QString err = status ? QStringLiteral("HTTP %1").arg(status) : QString::fromUtf8(body);
        qWarning().noquote() << "api (browser)" << r.verb << url.path() << "failed:" << err;
        if (r.fail)
            r.fail(status, err);
    });
}

void SoundCloudApi::rememberTrack(const QJsonObject &track)
{
    if (sc::isStub(track) || !track.contains(QLatin1StringView("media")))
        return;
    m_tracks.insert(track.value(QLatin1StringView("id")).toInteger(), track);
}

void SoundCloudApi::fetchTracks(const QList<qint64> &ids, QObject *context, std::function<void()> done)
{
    QStringList missing;
    for (qint64 id : ids) {
        if (!m_tracks.contains(id))
            missing.append(QString::number(id));
    }
    if (missing.isEmpty()) {
        done();
        return;
    }
    auto pending = std::make_shared<int>(0);
    for (int i = 0; i < missing.size(); i += 50) {
        ++*pending;
        QUrlQuery q;
        q.addQueryItem(QStringLiteral("ids"), missing.mid(i, 50).join(u','));
        auto finished = [pending, done](auto &&...) { if (--*pending == 0) done(); };
        get(QStringLiteral("/tracks"), q, context, finished, finished);
    }
}

static QVariantMap withArtwork(QVariantMap m, const QString &art)
{
    m[QStringLiteral("artwork")] = sc::artwork(art, QStringLiteral("t300x300"));
    m[QStringLiteral("artworkLarge")] = sc::artwork(art, QStringLiteral("t500x500"));
    m.remove(QStringLiteral("artworkPending"));
    return m;
}

void SoundCloudApi::resolveArtwork(const QVariantList &items, QObject *context,
                                   std::function<void(int, const QVariantMap &)> update, std::function<void()> done)
{
    auto pending = std::make_shared<int>(1);  // released at the end of this function
    auto settle = [pending, done] {
        if (--*pending == 0 && done)
            done();
    };
    QList<qint64> trackIds;
    QList<int> byTrack;
    for (int i = 0; i < items.size(); ++i) {
        const QVariantMap m = items.at(i).toMap();
        if (!m.value(QStringLiteral("artworkPending")).toBool())
            continue;
        const qint64 trackId = m.value(QStringLiteral("artworkTrackId")).toLongLong();
        if (trackId) {
            trackIds.append(trackId);
            byTrack.append(i);
            continue;
        }
        ++*pending;
        QUrlQuery q;
        q.addQueryItem(QStringLiteral("representation"), QStringLiteral("full"));
        get(QStringLiteral("/playlists/%1").arg(m.value(QStringLiteral("id")).toLongLong()), q, context,
            [update, settle, i, m](const QJsonDocument &doc) {
                const QVariantMap full = sc::playlistItem(doc.object());
                QString art = full.value(QStringLiteral("artworkLarge")).toString();
                update(i, art.isEmpty() ? withArtwork(m, m.value(QStringLiteral("artworkFallback")).toString())
                                        : withArtwork(m, art));
                settle();
            },
            [update, settle, i, m](int, const QString &) {
                update(i, withArtwork(m, m.value(QStringLiteral("artworkFallback")).toString()));
                settle();
            });
    }
    if (!trackIds.isEmpty()) {
        ++*pending;
        fetchTracks(trackIds, context, [this, items, byTrack, trackIds, update, settle] {
            for (int k = 0; k < byTrack.size(); ++k) {
                const QVariantMap m = items.at(byTrack.at(k)).toMap();
                const QJsonObject t = m_tracks.value(trackIds.at(k));
                QString art = t.value(QLatin1StringView("artwork_url")).toString();
                if (art.isEmpty())
                    art = m.value(QStringLiteral("artworkFallback")).toString();
                update(byTrack.at(k), withArtwork(m, art));
            }
            settle();
        });
    }
    settle();
}

void SoundCloudApi::callback(const QJSValue &cb, const QVariant &result, const QString &error)
{
    if (!cb.isCallable())
        return;
    QJSEngine *engine = qjsEngine(this);
    if (!engine)
        return;
    QJSValue fn = cb;
    fn.call({engine->toScriptValue(result), QJSValue(error)});
}

void SoundCloudApi::request(const QString &path, const QVariantMap &query, const QJSValue &callback)
{
    QUrlQuery q;
    for (auto it = query.begin(); it != query.end(); ++it)
        q.addQueryItem(it.key(), it.value().toString());
    get(path, q, this, [this, callback](const QJsonDocument &doc) {
        this->callback(callback, doc.toVariant());
    }, [this, callback](int, const QString &err) { this->callback(callback, {}, err); });
}

static QVariantList itemsOf(const QJsonArray &arr)
{
    QVariantList out;
    for (const QJsonValue &v : arr) {
        QVariantMap m = sc::item(v.toObject());
        if (!m.isEmpty())
            out.append(m);
    }
    return out;
}

void SoundCloudApi::loadHome(const QJSValue &callback)
{
    struct State {
        QVariantList recent, selections;
        int pending = 2;
        QString error;
    };
    auto st = std::make_shared<State>();
    auto finish = [this, st, callback] {
        if (--st->pending > 0)
            return;
        auto shelves = std::make_shared<QVariantList>();
        if (!st->recent.isEmpty())
            shelves->append(QVariantMap{{QStringLiteral("title"), QStringLiteral("Recently played")},
                                        {QStringLiteral("items"), st->recent}});
        *shelves += st->selections;
        // all shelves' items in one list, so their covers resolve in one batch
        QVariantList flat;
        QList<std::pair<int, int>> where;
        for (int s = 0; s < shelves->size(); ++s) {
            const QVariantList items = shelves->at(s).toMap().value(QStringLiteral("items")).toList();
            for (int i = 0; i < items.size(); ++i) {
                flat.append(items.at(i));
                where.append({s, i});
            }
        }
        const QString error = shelves->isEmpty() ? st->error : QString();
        resolveArtwork(flat, this, [shelves, where](int k, const QVariantMap &item) {
            QVariantMap shelf = (*shelves)[where.at(k).first].toMap();
            QVariantList items = shelf.value(QStringLiteral("items")).toList();
            items[where.at(k).second] = item;
            shelf[QStringLiteral("items")] = items;
            (*shelves)[where.at(k).first] = shelf;
        }, [this, shelves, callback, error] { this->callback(callback, *shelves, error); });
    };

    QUrlQuery qh;
    qh.addQueryItem(QStringLiteral("limit"), QStringLiteral("24"));
    get(QStringLiteral("/me/play-history/tracks"), qh, this, [st, finish](const QJsonDocument &doc) {
        // the history repeats tracks played more than once
        QSet<qint64> seen;
        for (const QVariant &v : itemsOf(doc.object().value(QLatin1StringView("collection")).toArray())) {
            const qint64 id = v.toMap().value(QStringLiteral("id")).toLongLong();
            if (!seen.contains(id)) {
                seen.insert(id);
                st->recent.append(v);
            }
        }
        finish();
    }, [st, finish](int, const QString &err) { st->error = err; finish(); });

    QUrlQuery qs;
    qs.addQueryItem(QStringLiteral("limit"), QStringLiteral("10"));
    get(QStringLiteral("/mixed-selections"), qs, this, [st, finish](const QJsonDocument &doc) {
        for (const QJsonValue &v : doc.object().value(QLatin1StringView("collection")).toArray()) {
            const QJsonObject sel = v.toObject();
            const QVariantList items =
                itemsOf(sel.value(QLatin1StringView("items")).toObject().value(QLatin1StringView("collection")).toArray());
            if (items.isEmpty())
                continue;
            st->selections.append(QVariantMap{
                {QStringLiteral("title"), sel.value(QLatin1StringView("title")).toString()},
                {QStringLiteral("description"), sel.value(QLatin1StringView("description")).toString()},
                {QStringLiteral("items"), items}});
        }
        finish();
    }, [st, finish](int, const QString &err) { st->error = err; finish(); });
}

void SoundCloudApi::loadPlaylist(const QVariant &idOrUrn, const QJSValue &callback)
{
    const QString key = idOrUrn.toString();
    if (key.isEmpty() || key.endsWith(u':')) {
        this->callback(callback, {}, QStringLiteral("no playlist id"));
        return;
    }
    QString path;
    QUrlQuery q;
    if (key.contains(QLatin1StringView("system-playlists"))) {
        path = QStringLiteral("/system-playlists/") + key;
    } else if (key.contains(QLatin1StringView("stations"))) {
        path = QStringLiteral("/stations/") + key;
    } else {
        path = QStringLiteral("/playlists/") + key.section(u':', -1);
        q.addQueryItem(QStringLiteral("representation"), QStringLiteral("full"));
    }
    get(path, q, this, [this, callback](const QJsonDocument &doc) {
        const QJsonObject p = doc.object();
        const QJsonArray tracks = p.value(QLatin1StringView("tracks")).toArray();
        QList<qint64> ids;
        for (const QJsonValue &t : tracks)
            ids.append(t.toObject().value(QLatin1StringView("id")).toInteger());
        fetchTracks(ids, this, [this, p, ids, callback] {
            QVariantMap info = sc::playlistItem(p);
            info[QStringLiteral("description")] = p.value(QLatin1StringView("description")).toString();
            QVariantList items;
            for (qint64 id : ids) {
                const QJsonObject t = m_tracks.value(id);
                if (!t.isEmpty())
                    items.append(sc::trackItem(t));
            }
            this->callback(callback, QVariantMap{{QStringLiteral("info"), info}, {QStringLiteral("items"), items}});
        });
    }, [this, callback](int, const QString &err) { this->callback(callback, {}, err); });
}

void SoundCloudApi::loadUser(const QVariant &id, const QJSValue &callback)
{
    get(QStringLiteral("/users/") + id.toString(), {}, this, [this, callback](const QJsonDocument &doc) {
        this->callback(callback, sc::userItem(doc.object()));
    }, [this, callback](int, const QString &err) { this->callback(callback, {}, err); });
}

void SoundCloudApi::resolve(const QString &url, const QJSValue &callback)
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("url"), url.trimmed());
    get(QStringLiteral("/resolve"), q, this, [this, callback](const QJsonDocument &doc) {
        this->callback(callback, sc::item(doc.object()));
    }, [this, callback](int, const QString &err) { this->callback(callback, {}, err); });
}

void SoundCloudApi::fetchLikedIds()
{
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("limit"), QStringLiteral("5000"));
    get(QStringLiteral("/me/track_likes/ids"), q, this, [this](const QJsonDocument &doc) {
        m_liked.clear();  // a refresh also drops what was unliked elsewhere
        for (const QJsonValue &v : doc.object().value(QLatin1StringView("collection")).toArray())
            m_liked.insert(v.toInteger());
        ++m_likesRevision;
        emit likesChanged();
    }, [this](int, const QString &) {
        // fall back to the most recent likes, enough for what is usually on screen
        QUrlQuery q2;
        q2.addQueryItem(QStringLiteral("limit"), QStringLiteral("200"));
        get(QStringLiteral("/users/%1/track_likes").arg(userId()), q2, this, [this](const QJsonDocument &doc) {
            for (const QJsonValue &v : doc.object().value(QLatin1StringView("collection")).toArray())
                m_liked.insert(v.toObject().value(QLatin1StringView("track")).toObject().value(QLatin1StringView("id")).toInteger());
            ++m_likesRevision;
            emit likesChanged();
        });
    });
}

void SoundCloudApi::refreshLikedIds()
{
    if (ready())
        fetchLikedIds();
}

bool SoundCloudApi::isLiked(const QVariant &trackId) const
{
    return m_liked.contains(trackId.toLongLong());
}

void SoundCloudApi::setLiked(const QVariant &trackId, bool liked)
{
    const qint64 id = trackId.toLongLong();
    if (!id || !ready() || isLiked(trackId) == liked)
        return;
    auto apply = [this, id](bool on) {
        if (on)
            m_liked.insert(id);
        else
            m_liked.remove(id);
        ++m_likesRevision;
        emit likesChanged();
        // the track as lists show it (the full object is cached: it was on screen to be liked)
        const QJsonObject t = m_tracks.value(id);
        emit likeChanged(t.isEmpty() ? QVariantMap{{QStringLiteral("kind"), QStringLiteral("track")}, {QStringLiteral("id"), id}}
                                     : sc::trackItem(t), on);
    };
    apply(liked);  // optimistic
    send(liked ? "PUT" : "DELETE", QStringLiteral("/users/%1/track_likes/%2").arg(userId()).arg(id), {}, this, {},
         [this, apply, liked](int, const QString &err) {
             apply(!liked);
             emit error(QStringLiteral("Could not %1 the track (%2)").arg(liked ? QStringLiteral("like") : QStringLiteral("unlike"), err));
         });
}
