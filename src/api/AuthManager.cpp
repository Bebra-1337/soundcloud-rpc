#include "api/AuthManager.h"

#include "api/WebProfile.h"

#include <QDir>
#include <QFile>
#include <QNetworkCookie>
#include <QTimer>
#include <QWebEngineCookieStore>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineView>

static QString configDir()
{
    return QDir::homePath() + QStringLiteral("/.config/soundcloud_rpc");
}

static QString tokenPath()
{
    return configDir() + QStringLiteral("/token");
}

AuthManager::AuthManager(QObject *parent) : QObject(parent) {}

AuthManager::~AuthManager()
{
    // the page goes before the shared profile (destroyed by Application at exit)
    delete m_view.data();
}

void AuthManager::start()
{
    QFile f(tokenPath());
    if (f.open(QIODevice::ReadOnly)) {
        const QString token = QString::fromUtf8(f.readAll()).trimmed();
        if (!token.isEmpty()) {
            m_token = token;
            emit tokenChanged(m_token);
            return;
        }
    }
    signIn();
}

void AuthManager::signIn()
{
    if (m_profile) {
        showWindow();
        return;
    }
    createProfile();
    // An already signed-in profile reports its cookies right away; only show the page when none arrives.
    m_waitForCookie = new QTimer(this);
    m_waitForCookie->setSingleShot(true);
    connect(m_waitForCookie, &QTimer::timeout, this, &AuthManager::showWindow);
    m_waitForCookie->start(m_clearCookies ? 0 : 4000);  // a cold Chromium start takes a while
    m_profile->cookieStore()->loadAllCookies();
}

void AuthManager::signOut()
{
    m_rejected = m_token;
    saveToken({});
    m_token.clear();
    emit tokenChanged(m_token);
    m_clearCookies = true;
    teardown();
    signIn();
}

void AuthManager::rejectToken(const QString &token)
{
    if (token != m_token || token.isEmpty())
        return;
    qWarning() << "SoundCloud rejected the saved session, signing in again";
    m_rejected = token;
    saveToken({});
    m_token.clear();
    emit tokenChanged(m_token);
    signIn();
}

void AuthManager::createProfile()
{
    m_profile = webprofile::acquire();
    if (m_clearCookies) {
        m_profile->cookieStore()->deleteAllCookies();
        m_clearCookies = false;
    }
    connect(m_profile->cookieStore(), &QWebEngineCookieStore::cookieAdded, this, &AuthManager::onCookie);
    emit signingInChanged();
}

void AuthManager::onCookie(const QNetworkCookie &cookie)
{
    if (cookie.name() != "oauth_token" || !cookie.domain().contains(QLatin1StringView("soundcloud.com")))
        return;
    const QString token = QString::fromUtf8(cookie.value());
    if (token.isEmpty() || token == m_rejected)
        return;  // the stale cookie of a session the API already turned down
    // let the call stack that delivered the cookie unwind before the profile is destroyed
    QMetaObject::invokeMethod(this, [this, token] { accept(token); }, Qt::QueuedConnection);
}

void AuthManager::showWindow()
{
    if (!m_profile)
        return;
    if (!m_view) {
        m_view = new QWebEngineView();
        m_view->setAttribute(Qt::WA_DeleteOnClose);
        m_view->setWindowTitle(QStringLiteral("Sign in to SoundCloud"));
        m_view->resize(1000, 720);
        m_view->setPage(new QWebEnginePage(m_profile, m_view));
        m_view->setUrl(QUrl(QStringLiteral("https://soundcloud.com/signin")));
    }
    m_view->show();
    m_view->raise();
    m_view->activateWindow();
}

void AuthManager::accept(const QString &token)
{
    if (!m_profile)
        return;
    m_rejected.clear();
    saveToken(token);
    teardown();
    if (token != m_token) {
        m_token = token;
        emit tokenChanged(m_token);
    }
}

void AuthManager::teardown()
{
    if (m_waitForCookie) {
        m_waitForCookie->deleteLater();
        m_waitForCookie = nullptr;
    }
    // pages must go before their profile
    delete m_view.data();
    if (m_profile) {
        m_profile->cookieStore()->disconnect(this);
        m_profile = nullptr;
        webprofile::release();
        emit signingInChanged();
    }
}

void AuthManager::saveToken(const QString &token)
{
    QDir().mkpath(configDir());
    if (token.isEmpty()) {
        QFile::remove(tokenPath());
        return;
    }
    QFile f(tokenPath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    f.write(token.toUtf8());
}
