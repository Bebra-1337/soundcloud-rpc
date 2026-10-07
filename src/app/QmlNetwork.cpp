#include "app/QmlNetwork.h"

#include "api/DiskCache.h"

#include <QCoreApplication>
#include <QMutex>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkReply>
#include <QPointer>
#include <QSet>
#include <QThread>

namespace {

QMutex goneLock;
QSet<QString> gone;

// The pixmap reader's disk cache. It lives in that thread, so the settings reach it through queued calls.
QMutex cacheLock;
QPointer<QNetworkDiskCache> imageCache;
qint64 cacheLimit = 300ll * 1024 * 1024;

class QmlNetwork : public QNetworkAccessManager
{
public:
    using QNetworkAccessManager::QNetworkAccessManager;

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request, QIODevice *data) override
    {
        QNetworkReply *reply = QNetworkAccessManager::createRequest(op, request, data);
        // connected before the pixmap reader sees the reply, so the URL is recorded before QML gets the error
        connect(reply, &QNetworkReply::finished, reply, [reply] {
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (status >= 400 && status < 500) {
                QMutexLocker lock(&goneLock);
                // a bound for clients running for days; dropping the set only costs a retry of an old dead URL
                if (gone.size() >= 5000)
                    gone.clear();
                gone.insert(reply->request().url().toString());
            }
        });
        return reply;
    }
};

} // namespace

QNetworkAccessManager *QmlNetworkFactory::create(QObject *parent)
{
    auto *nam = new QmlNetwork(parent);
    // Images load in the pixmap reader's thread; the engine's own manager (main thread) gets no disk cache, so
    // one directory never has two QNetworkDiskCache instances managing it.
    QMutexLocker lock(&cacheLock);
    if (QThread::currentThread() != QCoreApplication::instance()->thread() && !imageCache) {
        auto *cache = new QNetworkDiskCache(nam);
        cache->setCacheDirectory(diskcache::path(QStringLiteral("images")));
        cache->setMaximumCacheSize(cacheLimit);
        nam->setCache(cache);
        imageCache = cache;
    }
    return nam;
}

void QmlNetworkFactory::setCacheLimit(qint64 bytes)
{
    QMutexLocker lock(&cacheLock);
    cacheLimit = bytes;
    if (imageCache)
        QMetaObject::invokeMethod(imageCache, [cache = imageCache, bytes] {
            if (cache)
                cache->setMaximumCacheSize(bytes);
        });
}

void QmlNetworkFactory::clearCache()
{
    QMutexLocker lock(&cacheLock);
    if (imageCache)
        QMetaObject::invokeMethod(imageCache, [cache = imageCache] {
            if (cache)
                cache->clear();
        });
    else
        diskcache::remove(QStringLiteral("images"));
}

bool QmlNetworkFactory::isGone(const QString &url)
{
    QMutexLocker lock(&goneLock);
    return gone.contains(url);
}
