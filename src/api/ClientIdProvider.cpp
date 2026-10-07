#include "api/ClientIdProvider.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QSettings>

#include <algorithm>

static constexpr auto kSettingsKey = "api/clientId";

ClientIdProvider::ClientIdProvider(QNetworkAccessManager *nam, const QByteArray &userAgent, QObject *parent)
    : QObject(parent), m_nam(nam), m_userAgent(userAgent)
{
    m_clientId = QSettings().value(QLatin1StringView(kSettingsKey)).toString();
}

void ClientIdProvider::refresh()
{
    if (m_refreshing)
        return;
    m_refreshing = true;
    m_scripts.clear();

    QNetworkRequest req(QUrl(QStringLiteral("https://soundcloud.com/")));
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            finish({}, reply->errorString());
            return;
        }
        static const QRegularExpression re(QStringLiteral(R"re(src="(https://a-v2\.sndcdn\.com/assets/[^"]+\.js)")re"));
        const QString html = QString::fromUtf8(reply->readAll());
        for (auto it = re.globalMatch(html); it.hasNext();)
            m_scripts.append(it.next().captured(1));
        // the id lives in one of the last bundles: scan from the end
        std::reverse(m_scripts.begin(), m_scripts.end());
        scanNext();
    });
}

void ClientIdProvider::scanNext()
{
    if (m_scripts.isEmpty()) {
        finish({}, QStringLiteral("client_id not found in soundcloud.com bundles"));
        return;
    }
    QNetworkRequest req(QUrl(m_scripts.takeFirst()));
    req.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        static const QRegularExpression re(QStringLiteral(R"re(client_id["']?\s*[:=]\s*["']?([A-Za-z0-9]{32}))re"));
        const auto match = re.match(QString::fromUtf8(reply->readAll()));
        if (match.hasMatch())
            finish(match.captured(1));
        else
            scanNext();
    });
}

void ClientIdProvider::finish(const QString &id, const QString &error)
{
    m_refreshing = false;
    if (id.isEmpty()) {
        qWarning() << "client_id refresh failed:" << error;
        emit failed(error);
        return;
    }
    m_clientId = id;
    QSettings().setValue(QLatin1StringView(kSettingsKey), id);
    emit ready(id);
}
