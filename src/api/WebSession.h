#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <functional>

class QWebEngineProfile;
class QWebEngineView;
class QTimer;
class WebSessionPage;

// Sends the API requests that DataDome (soundcloud.com's anti-bot layer) refuses from a plain HTTP client, such
// as liking a track: a hidden soundcloud.com page in the user's own browser profile runs them with the page's
// fetch(), exactly as the website does, so DataDome's own script in that page sees a real browser. If DataDome
// still wants a captcha, the page is shown so the user can solve it, and the request is sent again.
// Chromium only runs while there is such a request: the page closes after a while without one.
class WebSession : public QObject
{
    Q_OBJECT
public:
    using Done = std::function<void(int status, const QByteArray &body)>;

    explicit WebSession(QObject *parent = nullptr);
    ~WebSession() override;

    void setToken(const QString &token) { m_token = token; }
    // url: the full api-v2 URL including client_id
    void send(const QByteArray &verb, const QUrl &url, const QByteArray &body, QObject *context, Done done);

private:
    struct Request {
        int id = 0;
        QByteArray verb;
        QUrl url;
        QByteArray body;
        QPointer<QObject> context;
        Done done;
        bool challenged = false;  // already went through a captcha once
    };

    void ensurePage();
    void run(const Request &r);
    void flush();
    void onConsole(const QString &message);
    void showChallenge();
    void onChallengeSolved();
    void teardown();

    QString m_token;
    QWebEngineProfile *m_profile = nullptr;
    WebSessionPage *m_page = nullptr;
    QPointer<QWebEngineView> m_view;
    bool m_ready = false;
    QList<Request> m_queue;          // waiting for the page (or a solved captcha)
    QHash<int, Request> m_inflight;  // running in the page
    int m_nextId = 1;
    QTimer *m_idle;
};
