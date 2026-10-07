#include "api/WebProfile.h"

#include <QCoreApplication>
#include <QDir>
#include <QTimer>
#include <QPointer>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineScriptCollection>

#include <utility>

// Same patches as the old web client: soundcloud.com sits behind Cloudflare/DataDome, which reject an obvious
// embedded browser.
static const char *kStealthJs = R"JS(
Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
if (!window.chrome) {
    window.chrome = { runtime: {}, loadTimes: function() {}, csi: function() {}, app: {} };
}
Object.defineProperty(navigator, 'languages', { get: () => ['ru-RU', 'ru', 'en-US', 'en'] });
if (!navigator.plugins || navigator.plugins.length === 0) {
    Object.defineProperty(navigator, 'plugins', {
        get: () => [
            { name: 'PDF Viewer', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
            { name: 'Chrome PDF Viewer', filename: 'mhjfbgofeelibecpbjeoegjhbcgbbolf', description: 'Google Chrome PDF Viewer' }
        ]
    });
}
)JS";

namespace webprofile {

static QPointer<QWebEngineProfile> s_profile;
static int s_users = 0;

QWebEngineProfile *acquire()
{
    ++s_users;
    if (s_profile)
        return s_profile;

    const QString storage = QDir::homePath() + QStringLiteral("/.config/soundcloud_rpc/storage");
    QDir().mkpath(storage);
    auto *profile = new QWebEngineProfile(QStringLiteral("soundcloud_profile"));
    profile->setPersistentStoragePath(storage);
    profile->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);

    // strip "QtWebEngine/x.y" from the User-Agent, a bot-check giveaway
    QStringList ua = profile->httpUserAgent().split(u' ');
    ua.removeIf([](const QString &part) { return part.startsWith(QLatin1StringView("QtWebEngine")); });
    profile->setHttpUserAgent(ua.join(u' '));

    QWebEngineScript stealth;
    stealth.setName(QStringLiteral("stealth"));
    stealth.setSourceCode(QString::fromUtf8(kStealthJs));
    stealth.setInjectionPoint(QWebEngineScript::DocumentCreation);
    stealth.setWorldId(QWebEngineScript::MainWorld);
    stealth.setRunsOnSubFrames(true);
    profile->scripts()->insert(stealth);

    s_profile = profile;
    return profile;
}

void release()
{
    if (s_users == 0 || --s_users > 0)
        return;
    // let pages released in the same breath go first, and keep the profile when someone takes it right back
    QTimer::singleShot(1000, qApp, [] {
        if (s_users == 0 && s_profile)
            std::exchange(s_profile, nullptr)->deleteLater();
    });
}

void destroyNow()
{
    delete s_profile.data();
    s_users = 0;
}

} // namespace webprofile
