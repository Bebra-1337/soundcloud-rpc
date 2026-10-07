#include "app/Application.h"

#include "api/AuthManager.h"
#include "api/Entities.h"
#include "api/SoundCloudApi.h"
#include "api/WebProfile.h"
#include "integrations/DiscordPresence.h"
#include "integrations/Mpris.h"
#include "models/PagedListModel.h"
#include "player/AudioAnalyser.h"
#include "player/PlayerController.h"

#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QClipboard>
#include <QCloseEvent>
#include <QDesktopServices>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QSettings>
#include <QSurfaceFormat>
#include <QSystemTrayIcon>
#include <QTimer>

static const QString kDefaultIdleTheme = QStringLiteral("GlassCard");
static const std::pair<const char *, const char *> kIdleThemes[] = {
    {"GlassCard", "Glass Card"},     {"BlurCover", "Blur Cover"}, {"Aurora", "Aurora"},
    {"Vinyl", "Vinyl"},              {"Cassette", "Cassette"},    {"Particles", "Particles"},
    {"Equalizer", "Equalizer"},      {"Stereo", "Stereo Mirror"}, {"Polaroid", "Polaroid"},
    {"MinimalClock", "Minimal Clock"}, {"Typography", "Typography"}, {"Neon", "Neon"},
    {"AlbumWall", "Album Wall"},     {"Orbit", "Orbit"},          {"Starfield", "Starfield"},
};

static bool isKnownTheme(const QString &key)
{
    for (const auto &[k, label] : kIdleThemes) {
        if (key == QLatin1StringView(k))
            return true;
    }
    return false;
}

Application::Application(bool minimized, const QStringList &urls, QObject *parent)
    : QObject(parent), m_pendingUrls(urls)
{
    m_api = new SoundCloudApi(this);
    m_auth = new AuthManager(this);
    m_player = new PlayerController(m_api, this);
    m_analyser = new AudioAnalyser(m_player->mediaPlayer(), this);
    m_discord = new DiscordPresence(m_player, this);
    m_mpris = new Mpris(m_player, this, this);

    connect(m_auth, &AuthManager::tokenChanged, m_api, &SoundCloudApi::setToken);
    connect(m_api, &SoundCloudApi::authRejected, m_auth, &AuthManager::rejectToken);
    connect(m_api, &SoundCloudApi::error, this, &Application::toast);
    connect(m_player, &PlayerController::message, this, &Application::toast);
    connect(m_api, &SoundCloudApi::readyChanged, this, [this] {
        if (!m_api->ready())
            return;
        for (const QString &url : std::exchange(m_pendingUrls, {}))
            openSoundCloudUrl(url);
    });

    const QString theme = QSettings().value(QStringLiteral("idle/theme"), kDefaultIdleTheme).toString();
    m_idleTheme = isKnownTheme(theme) ? theme : kDefaultIdleTheme;

    qmlRegisterSingletonInstance("ScBackend", 1, 0, "App", this);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Api", m_api);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Auth", m_auth);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Player", m_player);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Analyser", m_analyser);
    qmlRegisterType<PagedListModel>("ScBackend", 1, 0, "PagedListModel");

    m_engine = new QQmlApplicationEngine(this);
    m_engine->loadFromModule("SoundCloudRpc", "Main");
    if (!m_engine->rootObjects().isEmpty())
        m_window = qobject_cast<QQuickWindow *>(m_engine->rootObjects().constFirst());
    if (!m_window) {
        qCritical() << "QML failed to load";
        QMetaObject::invokeMethod(qApp, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
        return;
    }
    // Multisampling: Qt Quick edges are hard by default, so slow motion (scaling, rotation) in the idle
    // themes moves them in whole-pixel steps. Must be set before the window is first shown.
    // The color depth must be asked for explicitly: with samples set and no sizes, NVIDIA's EGL picks an RGB565
    // config, which turned dark grays green ((13,13,13) -> (8,12,8): green has one more bit) and dithered
    // gradients into dot patterns.
    QSurfaceFormat fmt = m_window->format();
    fmt.setSamples(4);
    fmt.setRedBufferSize(8);
    fmt.setGreenBufferSize(8);
    fmt.setBlueBufferSize(8);
    m_window->setFormat(fmt);
    connect(m_window, &QQuickWindow::sceneGraphInitialized, this, [this] {
        const QSurfaceFormat actual = m_window->format();
        if (actual.redBufferSize() < 8 || actual.greenBufferSize() < 8 || actual.blueBufferSize() < 8)
            qWarning() << "The window got a low color depth surface, colors will band:" << actual;
    });
    m_window->installEventFilter(this);
    connect(m_window, &QWindow::visibleChanged, this, [this](bool visible) {
        if (!visible)
            setIdleActive(false);
    });

    createTray();
    if (minimized)
        qInfo() << "Starting SoundCloud Desktop minimized to system tray...";
    else
        m_window->show();

    m_auth->start();

    // Debug aid for checking layouts: SOUNDCLOUD_RPC_SCREENSHOT=out.png saves the window after a few seconds
    // and quits (works with QT_QPA_PLATFORM=offscreen, which cannot draw MultiEffect artwork).
    const QString shot = qEnvironmentVariable("SOUNDCLOUD_RPC_SCREENSHOT");
    if (!shot.isEmpty()) {
        m_window->show();
        QTimer::singleShot(qEnvironmentVariableIntegerValue("SOUNDCLOUD_RPC_SCREENSHOT_DELAY").value_or(4000), this,
                           [this, shot] {
                               m_window->grabWindow().save(shot);
                               quit();
                           });
    }
}

Application::~Application()
{
    // the engine's QML objects reference the backend singletons: destroy it first; then the web pages (sign-in,
    // the anti-bot fallback) before the browser profile they share
    delete m_engine;
    delete m_api;
    delete m_auth;
    webprofile::destroyNow();
}

bool Application::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window && event->type() == QEvent::Close && !m_quitting) {
        event->ignore();
        m_window->hide();
        return true;
    }
    return QObject::eventFilter(watched, event);
}

QVariantList Application::idleThemes() const
{
    QVariantList out;
    for (const auto &[key, label] : kIdleThemes)
        out.append(QVariantMap{{QStringLiteral("key"), QLatin1StringView(key)}, {QStringLiteral("label"), QLatin1StringView(label)}});
    return out;
}

void Application::setIdleTheme(const QString &key)
{
    if (!isKnownTheme(key) || key == m_idleTheme)
        return;
    m_idleTheme = key;
    QSettings().setValue(QStringLiteral("idle/theme"), key);
    if (m_themeGroup) {
        for (QAction *a : m_themeGroup->actions())
            a->setChecked(a->data().toString() == key);
    }
    emit idleThemeChanged();
}

void Application::setIdleActive(bool on)
{
    if (on == m_idleActive)
        return;
    m_idleActive = on;
    m_analyser->setActive(on);  // the analyser only runs while the screen is open
    emit idleActiveChanged();
}

void Application::showIdle()
{
    if (m_window && (!m_window->isVisible() || m_window->visibility() == QWindow::Minimized))
        raiseWindow();
    setIdleActive(true);
}

void Application::raiseWindow()
{
    if (!m_window)
        return;
    m_window->show();
    m_window->raise();
    m_window->requestActivate();
}

void Application::toggleWindow()
{
    if (m_window && m_window->isVisible())
        m_window->hide();
    else
        raiseWindow();
}

void Application::copyTrackLink()
{
    const QString url = m_player->current().value(QStringLiteral("permalinkUrl")).toString();
    if (url.isEmpty())
        return;
    QGuiApplication::clipboard()->setText(url);
    emit toast(QStringLiteral("Link copied"));
    if (m_tray && (!m_window || !m_window->isVisible()))
        m_tray->showMessage(QStringLiteral("SoundCloud Desktop"), QStringLiteral("Link copied to clipboard: %1").arg(url),
                            QSystemTrayIcon::Information, 2000);
}

void Application::copyLink(const QString &url)
{
    if (url.isEmpty())
        return;
    QGuiApplication::clipboard()->setText(url);
    emit toast(QStringLiteral("Link copied"));
}

void Application::openExternal(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

void Application::openSoundCloudUrl(const QString &url)
{
    const QUrl u(url.trimmed());
    if (!u.host().endsWith(QLatin1StringView("soundcloud.com")) && u.host() != QLatin1StringView("on.soundcloud.com")) {
        emit toast(QStringLiteral("Not a SoundCloud link"));
        return;
    }
    if (!m_api->ready()) {
        m_pendingUrls.append(url);
        return;
    }
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("url"), u.toString());
    m_api->get(QStringLiteral("/resolve"), q, this, [this](const QJsonDocument &doc) {
        const QVariantMap item = sc::item(doc.object());
        if (item.isEmpty())
            return;
        raiseWindow();
        emit openItemRequested(item);
    }, [this](int, const QString &err) { emit toast(QStringLiteral("Could not open the link (%1)").arg(err)); });
}

void Application::quit()
{
    m_quitting = true;
    if (m_tray)
        m_tray->hide();
    QApplication::quit();
}

void Application::createTray()
{
    m_tray = new QSystemTrayIcon(this);
    QIcon icon = QIcon::fromTheme(QStringLiteral("soundcloud-rpc"), QIcon(QStringLiteral(":/soundcloud.png")));
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("audio-player"), QIcon::fromTheme(QStringLiteral("audio-x-generic")));
    m_tray->setIcon(icon);
    m_tray->setToolTip(QStringLiteral("SoundCloud Desktop"));

    m_trayMenu = new QMenu();
    m_trayMenu->addAction(QStringLiteral("Play / Pause"), m_player, &PlayerController::togglePlay);
    m_trayMenu->addAction(QStringLiteral("Next"), m_player, &PlayerController::next);
    m_trayMenu->addAction(QStringLiteral("Previous"), m_player, &PlayerController::previous);
    m_trayMenu->addAction(QStringLiteral("Copy Track Link"), this, &Application::copyTrackLink);
    m_trayMenu->addAction(QStringLiteral("Show / Hide Window"), this, &Application::toggleWindow);
    m_trayMenu->addSeparator();
    createIdleMenu(m_trayMenu);
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(QStringLiteral("Sign Out"), m_auth, &AuthManager::signOut);
    m_trayMenu->addAction(QStringLiteral("Quit"), this, &Application::quit);

    m_tray->setContextMenu(m_trayMenu);
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger)
            toggleWindow();
    });
    connect(this, &QObject::destroyed, m_trayMenu, &QObject::deleteLater);
    m_tray->show();
}

void Application::createIdleMenu(QMenu *menu)
{
    QMenu *idle = menu->addMenu(QStringLiteral("Idle Screen"));
    idle->addAction(QStringLiteral("Show Idle Screen"), this, &Application::showIdle);
    idle->addSeparator();
    m_themeGroup = new QActionGroup(this);
    for (const auto &[key, label] : kIdleThemes) {
        QAction *a = idle->addAction(QLatin1StringView(label));
        a->setCheckable(true);
        a->setData(QLatin1StringView(key));
        a->setChecked(m_idleTheme == QLatin1StringView(key));
        m_themeGroup->addAction(a);
        connect(a, &QAction::triggered, this, [this, k = QString::fromLatin1(key)] { setIdleTheme(k); });
    }
}
