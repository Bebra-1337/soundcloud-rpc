#include "api/Entities.h"

#include <QJsonArray>
#include <QRegularExpression>

namespace sc {

QString artwork(const QString &url, const QString &size)
{
    if (url.isEmpty())
        return {};
    static const QRegularExpression re(QStringLiteral("-(large|t\\d+x\\d+|crop|small|tiny|badge|mini)\\.(jpg|jpeg|png)$"));
    QString out = url;
    out.replace(re, QStringLiteral("-%1.\\2").arg(size));
    return out;
}

static QString str(const QJsonObject &o, const char *key)
{
    return o.value(QLatin1StringView(key)).toString();
}

QVariantMap trackItem(const QJsonObject &t)
{
    const QJsonObject user = t.value(QLatin1StringView("user")).toObject();
    const qint64 id = t.value(QLatin1StringView("id")).toInteger();
    QString art = str(t, "artwork_url");
    if (art.isEmpty())
        art = str(user, "avatar_url");
    const QString policy = str(t, "policy");

    QVariantMap m;
    m[QStringLiteral("kind")] = QStringLiteral("track");
    m[QStringLiteral("id")] = id;
    m[QStringLiteral("urn")] = QStringLiteral("soundcloud:tracks:%1").arg(id);
    m[QStringLiteral("title")] = str(t, "title");
    m[QStringLiteral("artist")] = str(user, "username");
    m[QStringLiteral("userId")] = user.value(QLatin1StringView("id")).toInteger();
    m[QStringLiteral("artwork")] = artwork(art, QStringLiteral("t200x200"));
    m[QStringLiteral("artworkLarge")] = artwork(art, QStringLiteral("t500x500"));
    // some artwork URLs point at nothing; the site then shows the uploader's avatar
    m[QStringLiteral("artworkFallback")] = artwork(str(user, "avatar_url"), QStringLiteral("t500x500"));
    m[QStringLiteral("permalinkUrl")] = str(t, "permalink_url");
    m[QStringLiteral("waveformUrl")] = str(t, "waveform_url");
    m[QStringLiteral("genre")] = str(t, "genre");
    m[QStringLiteral("createdAt")] = str(t, "created_at");
    // Go+ tracks without a full stream for this account play a 30-second snippet ("snipped" transcoding);
    // stubs without media fall back to the policy
    const QJsonObject tc = pickTranscoding(t);
    const bool snippet = isStub(t) ? policy == QLatin1StringView("SNIP")
                                   : !tc.isEmpty() && tc.value(QLatin1StringView("snipped")).toBool();
    // SNIP tracks report the snippet length as duration and the real length as full_duration
    const qint64 duration = t.value(QLatin1StringView("duration")).toInteger();
    const qint64 fullDuration = t.value(QLatin1StringView("full_duration")).toInteger();
    m[QStringLiteral("durationMs")] = snippet || fullDuration <= 0 ? duration : fullDuration;
    m[QStringLiteral("fullDurationMs")] = fullDuration;
    m[QStringLiteral("likes")] = t.value(QLatin1StringView("likes_count")).toInteger();
    m[QStringLiteral("plays")] = t.value(QLatin1StringView("playback_count")).toInteger();
    m[QStringLiteral("snippet")] = snippet;
    // the full version exists, but only as DRM-encrypted HLS (Widevine): it plays in full on soundcloud.com only
    bool encryptedFull = false;
    for (const QJsonValue &v : t.value(QLatin1StringView("media")).toObject().value(QLatin1StringView("transcodings")).toArray()) {
        const QJsonObject o = v.toObject();
        if (str(o.value(QLatin1StringView("format")).toObject(), "protocol").contains(QLatin1StringView("encrypted"))
            && !o.value(QLatin1StringView("snipped")).toBool())
            encryptedFull = true;
    }
    m[QStringLiteral("fullOnlyOnSite")] = encryptedFull && (snippet || tc.isEmpty());
    m[QStringLiteral("stub")] = isStub(t);
    // stubs have no media yet; assume playable until the full object says otherwise
    m[QStringLiteral("playable")] = isStub(t) || !tc.isEmpty();
    return m;
}

QVariantMap playlistItem(const QJsonObject &p)
{
    const QJsonObject user = p.value(QLatin1StringView("user")).toObject();
    const QJsonArray tracks = p.value(QLatin1StringView("tracks")).toArray();
    QString kind = str(p, "kind");
    if (kind.isEmpty())
        kind = QStringLiteral("playlist");

    // Without artwork of its own a playlist shows its first track's cover, like on the site. Outside the
    // playlist's own page the tracks are mostly stubs (id only): then the cover is looked up later
    // (SoundCloudApi::resolveArtwork) and the owner's avatar is only the last resort.
    QVariantMap m;
    QString art = str(p, "artwork_url");
    if (art.isEmpty())
        art = str(p, "calculated_artwork_url");
    for (int i = 0; art.isEmpty() && i < tracks.size(); ++i) {
        const QJsonObject t = tracks.at(i).toObject();
        if (isStub(t)) {
            m[QStringLiteral("artworkTrackId")] = t.value(QLatin1StringView("id")).toInteger();
            break;
        }
        art = str(t, "artwork_url");
    }
    const bool canLookUp = m.contains(QStringLiteral("artworkTrackId"))
                           || (tracks.isEmpty() && p.value(QLatin1StringView("track_count")).toInt() > 0
                               && p.value(QLatin1StringView("id")).toInteger() != 0);
    m[QStringLiteral("artworkFallback")] = artwork(str(user, "avatar_url"), QStringLiteral("t500x500"));
    if (art.isEmpty() && canLookUp) {
        m[QStringLiteral("artworkPending")] = true;
    } else if (art.isEmpty()) {
        art = str(user, "avatar_url");
    }

    m[QStringLiteral("kind")] = kind;
    m[QStringLiteral("id")] = p.value(QLatin1StringView("id")).toVariant();
    m[QStringLiteral("urn")] = str(p, "urn");
    QString title = str(p, "title");
    if (title.isEmpty())
        title = str(p, "short_title");
    m[QStringLiteral("title")] = title;
    QString artist = str(user, "username");
    if (artist.isEmpty())
        artist = str(p, "short_description");
    if (artist.isEmpty() && kind != QLatin1StringView("playlist"))
        artist = QStringLiteral("SoundCloud");
    m[QStringLiteral("artist")] = artist;
    m[QStringLiteral("userId")] = user.value(QLatin1StringView("id")).toInteger();
    m[QStringLiteral("artwork")] = artwork(art, QStringLiteral("t300x300"));
    m[QStringLiteral("artworkLarge")] = artwork(art, QStringLiteral("t500x500"));
    m[QStringLiteral("permalinkUrl")] = str(p, "permalink_url");
    m[QStringLiteral("isAlbum")] = p.value(QLatin1StringView("is_album")).toBool()
                                   || str(p, "set_type") == QLatin1StringView("album");
    int count = p.value(QLatin1StringView("track_count")).toInt();
    if (count == 0)
        count = tracks.size();
    m[QStringLiteral("trackCount")] = count;
    m[QStringLiteral("durationMs")] = p.value(QLatin1StringView("duration")).toInteger();
    m[QStringLiteral("playable")] = true;
    return m;
}

QVariantMap userItem(const QJsonObject &u)
{
    QVariantMap m;
    m[QStringLiteral("kind")] = QStringLiteral("user");
    m[QStringLiteral("id")] = u.value(QLatin1StringView("id")).toInteger();
    m[QStringLiteral("urn")] = str(u, "urn");
    m[QStringLiteral("title")] = str(u, "username");
    QString sub = str(u, "full_name");
    if (sub.isEmpty())
        sub = str(u, "city");
    m[QStringLiteral("artist")] = sub;
    m[QStringLiteral("artwork")] = artwork(str(u, "avatar_url"), QStringLiteral("t200x200"));
    m[QStringLiteral("artworkLarge")] = artwork(str(u, "avatar_url"), QStringLiteral("t500x500"));
    m[QStringLiteral("permalinkUrl")] = str(u, "permalink_url");
    m[QStringLiteral("followers")] = u.value(QLatin1StringView("followers_count")).toInteger();
    m[QStringLiteral("trackCount")] = u.value(QLatin1StringView("track_count")).toInt();
    m[QStringLiteral("description")] = str(u, "description");
    m[QStringLiteral("playable")] = true;
    return m;
}

static QVariantMap entity(const QJsonObject &o, const QString &fallbackKind)
{
    QString kind = str(o, "kind");
    if (kind.isEmpty())
        kind = fallbackKind;
    if (kind == QLatin1StringView("track"))
        return trackItem(o);
    if (kind == QLatin1StringView("user"))
        return userItem(o);
    QVariantMap m = playlistItem(o);  // playlist, system-playlist, station, ... all look like collections
    m[QStringLiteral("kind")] = kind;
    return m;
}

// Promo cards and other entries without an id or urn can't be opened or played: leave them out.
static QVariantMap usable(const QVariantMap &m)
{
    const bool hasId = m.value(QStringLiteral("id")).toLongLong() != 0;
    const bool hasUrn = !m.value(QStringLiteral("urn")).toString().isEmpty();
    return hasId || hasUrn ? m : QVariantMap();
}

static bool isEntityKind(const QString &kind)
{
    static const QStringList kinds = {
        QStringLiteral("track"), QStringLiteral("playlist"), QStringLiteral("system-playlist"), QStringLiteral("user"),
        QStringLiteral("station"), QStringLiteral("track-station"), QStringLiteral("artist-station"),
    };
    return kinds.contains(kind);
}

QVariantMap item(const QJsonObject &entry)
{
    // wrappers carry a kind of their own too ({"kind": "like", "track": {...}} in likes), so only a kind that
    // names an entity means the object is the entity itself
    if (isEntityKind(entry.value(QLatin1StringView("kind")).toString()))
        return usable(entity(entry, {}));

    static const std::pair<const char *, const char *> wrapped[] = {
        {"track", "track"},
        {"playlist", "playlist"},
        {"system_playlist", "system-playlist"},
        {"station", "station"},
        {"user", "user"},  // last: in the stream "user" is the reposter, next to the track
    };
    for (const auto &[key, kind] : wrapped) {
        const QJsonValue v = entry.value(QLatin1StringView(key));
        if (!v.isObject())
            continue;
        QVariantMap m = entity(v.toObject(), QLatin1StringView(kind));
        const QString type = str(entry, "type");
        if (type.endsWith(QLatin1StringView("-repost")) && qstrcmp(key, "user") != 0) {
            m[QStringLiteral("repostedBy")] = str(entry.value(QLatin1StringView("user")).toObject(), "username");
        }
        return usable(m);
    }
    return {};
}

bool isStub(const QJsonObject &track)
{
    return !track.contains(QLatin1StringView("title"));
}

QJsonObject pickTranscoding(const QJsonObject &track)
{
    if (str(track, "policy") == QLatin1StringView("BLOCK"))
        return {};
    const QJsonArray list = track.value(QLatin1StringView("media")).toObject().value(QLatin1StringView("transcodings")).toArray();
    QJsonObject best;
    int bestScore = 0;
    for (const QJsonValue &v : list) {
        const QJsonObject tc = v.toObject();
        const QJsonObject fmt = tc.value(QLatin1StringView("format")).toObject();
        const QString protocol = str(fmt, "protocol");
        const QString mime = str(fmt, "mime_type");
        const QString preset = str(tc, "preset");
        if (str(tc, "url").isEmpty() || protocol.contains(QLatin1StringView("encrypted")))
            continue;  // cbc-/ctr-encrypted-hls need a Widevine CDM
        int score = 0;
        if (protocol == QLatin1StringView("hls")) {
            if (mime.contains(QLatin1StringView("mp4a")) || mime.startsWith(QLatin1StringView("audio/mp4")))
                score = 40;
            else if (mime.contains(QLatin1StringView("mpeg")))
                score = 30;
            else if (mime.contains(QLatin1StringView("ogg")) || mime.contains(QLatin1StringView("opus")))
                score = 20;
            else
                score = 10;
        } else if (protocol == QLatin1StringView("progressive")) {
            score = 35;
        } else {
            continue;
        }
        if (preset.contains(QLatin1StringView("160")))
            score += 5;  // aac_160k (Go+) over aac_96k when the account gets both
        if (str(tc, "quality") == QLatin1StringView("hq"))
            score += 2;
        if (!tc.value(QLatin1StringView("snipped")).toBool())
            score += 100;  // a full stream always beats the 30-second preview, whatever its format
        if (score > bestScore) {
            bestScore = score;
            best = tc;
        }
    }
    return best;
}

bool isPlayable(const QJsonObject &track)
{
    return !pickTranscoding(track).isEmpty();
}

} // namespace sc
