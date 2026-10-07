#pragma once

#include <QJsonDocument>
#include <QString>

// Files under the cache directory (~/.cache/SoundCloud/soundcloud-rpc, XDG_CACHE_HOME respected):
//   images/      covers and avatars (QNetworkDiskCache of the QML engine, see QmlNetwork; size-limited)
//   waveforms/   downsampled waveforms by track id
//   api/         the signed-in account's last Home, Feed, Library pages, /me and liked ids: shown at once on
//                start (and offline) while fresh ones load. Removed on sign-out and when another account signs in.
// Everything here can be deleted at any time (settings: Clear cache).
namespace diskcache {

QString root();
QString path(const QString &relative);
QJsonDocument read(const QString &relative);
void write(const QString &relative, const QJsonDocument &doc);  // atomic (QSaveFile), creates the directories
void remove(const QString &relative);                           // a file or a whole directory
// bytes in the three directories above (Qt keeps its own caches next to them: qmlcache, QtWebEngine); walks the
// tree, blocking
qint64 size();
QString key(const QString &text);                               // a short file-name-safe hash

} // namespace diskcache
