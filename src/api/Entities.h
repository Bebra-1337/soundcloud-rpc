#pragma once

#include <QJsonObject>
#include <QString>
#include <QVariantMap>

// Conversion of api-v2 JSON into the flat maps the QML side works with. Every item has a "kind"
// ("track", "playlist", "system-playlist", "user", ...), an "id"/"urn", a "title", an "artist" (subtitle)
// and an "artwork" URL, so lists can mix kinds (search, library, feed).
namespace sc {

// "...-large.jpg" -> "...-t500x500.jpg"; size is "t200x200", "t300x300", "t500x500", ...
QString artwork(const QString &url, const QString &size);

QVariantMap trackItem(const QJsonObject &track);
QVariantMap playlistItem(const QJsonObject &playlist);
QVariantMap userItem(const QJsonObject &user);

// Any collection element: a plain entity (has "kind") or a wrapper such as {type, track, user} from the
// stream, {track} from likes/history or {playlist}/{system_playlist} from the library.
QVariantMap item(const QJsonObject &entry);

// Playlists carry full objects only for their first few tracks; the rest are stubs with just an id.
bool isStub(const QJsonObject &track);

// The best stream the client can play: non-encrypted HLS (AAC preferred) or progressive. Empty when the
// track is only offered as DRM-encrypted HLS (Widevine), which this client does not (and may not) decode.
QJsonObject pickTranscoding(const QJsonObject &track);
bool isPlayable(const QJsonObject &track);

} // namespace sc
