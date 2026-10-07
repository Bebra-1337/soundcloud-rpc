#pragma once

#include <QObject>
#include <QStringList>

class QNetworkAccessManager;

// The web player's client_id. SoundCloud no longer hands out API keys, so the client uses the same id as
// soundcloud.com itself: it is embedded in the site's JS bundles (a-v2.sndcdn.com/assets/*.js) and rotates
// now and then. Cached in QSettings; refresh() fetches it again (on start without cache, or when the API
// rejects the cached one).
class ClientIdProvider : public QObject
{
    Q_OBJECT
public:
    ClientIdProvider(QNetworkAccessManager *nam, const QByteArray &userAgent, QObject *parent = nullptr);

    QString clientId() const { return m_clientId; }
    bool refreshing() const { return m_refreshing; }
    void refresh();

signals:
    void ready(const QString &clientId);
    void failed(const QString &error);

private:
    void scanNext();
    void finish(const QString &id, const QString &error = {});

    QNetworkAccessManager *m_nam;
    QByteArray m_userAgent;
    QString m_clientId;
    QStringList m_scripts;
    bool m_refreshing = false;
};
