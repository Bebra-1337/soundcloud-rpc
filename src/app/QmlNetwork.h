#pragma once

#include <QQmlNetworkAccessManagerFactory>
#include <QString>

// Network access of the QML engine (artwork).
//  - Images are kept on disk (diskcache "images/", a QNetworkDiskCache with the limit from the settings): sndcdn.com
//    lets covers be reused for 42 days, so a cover seen once loads without the network afterwards.
//  - Remembers which URLs the server answered with a 4xx status, so ArtImage can tell an image that doesn't exist
//    (try the next size or the avatar right away) from one that only failed in transit (the CDN closing its
//    HTTP/2 connection mid-load: retry it).
class QmlNetworkFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override;

    // thread-safe: images load in the QML pixmap reader's thread
    static bool isGone(const QString &url);
    static void setCacheLimit(qint64 bytes);
    static void clearCache();
};
