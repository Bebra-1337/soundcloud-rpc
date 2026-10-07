#include "api/WebSession.h"

#include "api/WebProfile.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkCookie>
#include <QTimer>
#include <QWebEngineCookieStore>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineView>

static const QString kResultTag = QStringLiteral("SCRPC_RESULT:");
static constexpr int kIdleMs = 2 * 60 * 1000;
static constexpr int kSettleMs = 1500;           // let DataDome's script in the page initialise
static constexpr int kSilentChallengeMs = 6000;  // an invisible challenge usually clears in this time

// The page's own console carries the results back; everything else it logs is the website's noise.
class WebSessionPage : public QWebEnginePage
{
    Q_OBJECT
public:
    using QWebEnginePage::QWebEnginePage;

signals:
    void consoleMessage(const QString &message);

protected:
    void javaScriptConsoleMessage(JavaScriptConsoleMessageLevel, const QString &message, int, const QString &) override
    {
        if (message.startsWith(kResultTag))
            emit consoleMessage(message);
    }
};

// Runs one request with the page's fetch (patched by DataDome's script, which adds its client id) and reports
// "SCRPC_RESULT:<id>:<status>:<body>". Credentials are tried first; if CORS refuses them, without.
static const char *kFetchJs = R"JS(
(async () => {
    const r = %1;
    const opts = { method: r.method, headers: { 'Authorization': 'OAuth ' + r.token,
                                                'Accept': 'application/json, text/javascript, */*; q=0.01' } };
    if (r.body) {
        opts.body = r.body;
        opts.headers['Content-Type'] = 'application/json';
    }
    let res;
    try {
        res = await fetch(r.url, Object.assign({ credentials: 'include' }, opts));
    } catch (e) {
        try {
            res = await fetch(r.url, opts);
        } catch (e2) {
            console.log('SCRPC_RESULT:' + r.id + ':0:' + String(e2));
            return;
        }
    }
    const text = await res.text().catch(() => '');
    console.log('SCRPC_RESULT:' + r.id + ':' + res.status + ':' + text.slice(0, 4000));
})();
)JS";

WebSession::WebSession(QObject *parent) : QObject(parent), m_idle(new QTimer(this))
{
    m_idle->setSingleShot(true);
    m_idle->setInterval(kIdleMs);
    connect(m_idle, &QTimer::timeout, this, [this] {
        if (m_queue.isEmpty() && m_inflight.isEmpty() && !m_view)
            teardown();
        else
            m_idle->start();
    });
}

WebSession::~WebSession()
{
    // the page goes before the shared profile (destroyed by Application at exit)
    delete m_view.data();
    delete m_page;
}

void WebSession::send(const QByteArray &verb, const QUrl &url, const QByteArray &body, QObject *context, Done done)
{
    Request r{m_nextId++, verb, url, body, context, std::move(done)};
    m_idle->start();
    if (m_ready && !m_view) {
        run(r);
        return;
    }
    m_queue.append(r);
    ensurePage();
}

void WebSession::ensurePage()
{
    if (m_page)
        return;
    qInfo() << "Opening a hidden soundcloud.com page for a request the anti-bot layer only accepts from a browser";
    m_profile = webprofile::acquire();
    m_page = new WebSessionPage(m_profile, this);
    m_page->setAudioMuted(true);
    connect(m_page, &WebSessionPage::consoleMessage, this, &WebSession::onConsole);
    connect(m_page, &QWebEnginePage::loadFinished, this, [this](bool ok) {
        if (m_ready)
            return;
        if (!ok) {
            qWarning() << "soundcloud.com did not load in the hidden page";
            const auto queue = std::exchange(m_queue, {});
            for (const Request &r : queue) {
                if (r.context && r.done)
                    r.done(0, "soundcloud.com did not load");
            }
            teardown();
            return;
        }
        QTimer::singleShot(kSettleMs, this, [this] {
            m_ready = true;
            flush();
        });
    });
    // a solved challenge shows up as a fresh DataDome cookie
    connect(m_profile->cookieStore(), &QWebEngineCookieStore::cookieAdded, this, [this](const QNetworkCookie &c) {
        if (c.name() == "datadome")
            QMetaObject::invokeMethod(this, &WebSession::onChallengeSolved, Qt::QueuedConnection);
    });
    m_page->load(QUrl(QStringLiteral("https://soundcloud.com/")));
}

void WebSession::flush()
{
    if (!m_ready)
        return;
    const auto queue = std::exchange(m_queue, {});
    for (const Request &r : queue)
        run(r);
}

void WebSession::run(const Request &r)
{
    if (!r.context)
        return;
    m_inflight.insert(r.id, r);
    const QJsonObject req{{QStringLiteral("id"), r.id},
                          {QStringLiteral("method"), QString::fromLatin1(r.verb)},
                          {QStringLiteral("url"), r.url.toString(QUrl::FullyEncoded)},
                          {QStringLiteral("body"), QString::fromUtf8(r.body)},
                          {QStringLiteral("token"), m_token}};
    const QString js = QString::fromLatin1(kFetchJs).arg(QString::fromUtf8(QJsonDocument(req).toJson(QJsonDocument::Compact)));
    m_page->runJavaScript(js, QWebEngineScript::MainWorld);
}

void WebSession::onConsole(const QString &message)
{
    // SCRPC_RESULT:<id>:<status>:<body>
    const QString rest = message.mid(kResultTag.size());
    const int id = rest.section(u':', 0, 0).toInt();
    const int status = rest.section(u':', 1, 1).toInt();
    const QByteArray body = rest.section(u':', 2).toUtf8();
    if (!m_inflight.contains(id))
        return;
    Request r = m_inflight.take(id);
    m_idle->start();

    const bool dataDome = status == 403 && body.contains("captcha-delivery.com");
    if (dataDome && !r.challenged) {
        // Usually an invisible check that DataDome's script in the page clears by itself; if it doesn't, the
        // user gets the page to solve the captcha. Either way a new cookie triggers the retry.
        r.challenged = true;
        m_queue.append(r);
        QTimer::singleShot(kSilentChallengeMs, this, [this] {
            if (!m_queue.isEmpty())
                showChallenge();
        });
        return;
    }
    if (r.context && r.done)
        r.done(status, body);
}

void WebSession::showChallenge()
{
    if (m_view || !m_page)
        return;
    m_view = new QWebEngineView();
    m_view->setAttribute(Qt::WA_DeleteOnClose);
    m_view->setWindowTitle(QStringLiteral("SoundCloud: confirm you're not a robot"));
    m_view->resize(1000, 720);
    m_view->setPage(m_page);
    connect(m_view, &QObject::destroyed, this, [this] {
        // closed without solving: the waiting requests fail
        const auto queue = std::exchange(m_queue, {});
        for (const Request &r : queue) {
            if (r.context && r.done)
                r.done(403, "anti-bot check not completed");
        }
    });
    m_view->show();
    m_view->raise();
    m_view->activateWindow();
}

void WebSession::onChallengeSolved()
{
    if (m_queue.isEmpty() || !m_ready)
        return;
    if (m_view) {
        m_view->disconnect(this);
        m_view->setPage(nullptr);  // the page stays ours
        m_view->close();
    }
    flush();
}

void WebSession::teardown()
{
    delete m_view.data();
    delete m_page;
    m_page = nullptr;
    m_ready = false;
    if (m_profile) {
        m_profile->cookieStore()->disconnect(this);
        m_profile = nullptr;
        webprofile::release();
    }
}

#include "WebSession.moc"
