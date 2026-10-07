#include "api/DiskCache.h"

#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>

namespace diskcache {

QString root()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}

QString path(const QString &relative)
{
    return root() + u'/' + relative;
}

QJsonDocument read(const QString &relative)
{
    QFile f(path(relative));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(f.readAll());
}

void write(const QString &relative, const QJsonDocument &doc)
{
    const QString file = path(relative);
    QDir().mkpath(QFileInfo(file).absolutePath());
    QSaveFile f(file);
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(doc.toJson(QJsonDocument::Compact));
    f.commit();
}

void remove(const QString &relative)
{
    const QString p = path(relative);
    if (QFileInfo(p).isDir())
        QDir(p).removeRecursively();
    else
        QFile::remove(p);
}

qint64 size()
{
    qint64 total = 0;
    for (const char *dir : {"images", "waveforms", "api"}) {
        QDirIterator it(path(QLatin1StringView(dir)), QDir::Files | QDir::Hidden | QDir::NoSymLinks,
                        QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            total += it.fileInfo().size();
        }
    }
    return total;
}

QString key(const QString &text)
{
    return QString::fromLatin1(QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Sha1).toHex().left(16));
}

} // namespace diskcache
