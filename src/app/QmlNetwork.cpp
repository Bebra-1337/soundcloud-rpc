#include "app/QmlNetwork.h"

#include <QMutex>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSet>

namespace {

QMutex goneLock;
QSet<QString> gone;

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
    return new QmlNetwork(parent);
}

bool QmlNetworkFactory::isGone(const QString &url)
{
    QMutexLocker lock(&goneLock);
    return gone.contains(url);
}
