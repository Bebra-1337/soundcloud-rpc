#include "app/Application.h"
#include "app/QmlNetwork.h"

#ifdef Q_OS_LINUX
#include "app/ThemeWatcher.h"
#include "integrations/Mpris.h"
#endif

#include "api/AuthManager.h"
#include "api/DiskCache.h"
#include "api/Entities.h"
#include "api/SoundCloudApi.h"
#include "api/WebProfile.h"
#include "integrations/DiscordPresence.h"
#include "models/PagedListModel.h"
#include "player/AudioAnalyser.h"
#include "player/PlayerController.h"

#include <algorithm>

#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QClipboard>
#include <QCloseEvent>
#include <QDesktopServices>
#include <QMouseEvent>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QSettings>
#include <QSurfaceFormat>
#include <QSystemTrayIcon>
#include <QThreadPool>
#include <QTimer>

// labels are translated where they are shown (QT_TRANSLATE_NOOP only marks them for lupdate)
static const std::pair<const char *, const char *> kColorModes[] = {
    {"auto", QT_TRANSLATE_NOOP("Application", "Automatic")}, {"system", QT_TRANSLATE_NOOP("Application", "System colors")}, {"dark", QT_TRANSLATE_NOOP("Application", "Dark")}, {"light", QT_TRANSLATE_NOOP("Application", "Light")}};

static bool isKnownColorMode(const QString &mode)
{
    for (const auto &[k, label] : kColorModes) {
        if (mode == QLatin1StringView(k))
            return true;
    }
    return false;
}

static bool isKnownLogoStyle(const QString &style)
{
    return style == QLatin1StringView("auto") || style == QLatin1StringView("white") || style == QLatin1StringView("black");
}

static const std::pair<const char *, const char *> kLanguages[] = {
    {"system", QT_TRANSLATE_NOOP("Application", "System")}, {"en", "English"}, {"ru", "Русский"}};  // languages by their own names

static bool isKnownLanguage(const QString &language)
{
    for (const auto &[k, label] : kLanguages) {
        if (language == QLatin1StringView(k))
            return true;
    }
    return false;
}

static QString label(const char *text)
{
    return QCoreApplication::translate("Application", text);
}

static QVariantList keyLabelList(const auto &entries)
{
    QVariantList out;
    for (const auto &[key, text] : entries)
        out.append(QVariantMap{{QStringLiteral("key"), QLatin1StringView(key)}, {QStringLiteral("label"), label(text)}});
    return out;
}

// Automatic idle screen: shown after this long without input while music plays (settings: 5..60 s).
static constexpr int kIdleDelayDefault = 30;
static constexpr int kIdleDelayMin = 5;
static constexpr int kIdleDelayMax = 60;
static constexpr int kIdleMoveThreshold = 4;  // px the pointer must travel to count as input

static constexpr int kCacheLimitDefault = 300;  // MB
static constexpr int kCacheLimitMin = 50;
static constexpr int kCacheLimitMax = 2000;

static const QString kDefaultIdleTheme = QStringLiteral("GlassCard");
// The keys are stored in the settings and name the theme files; several themes were redesigned under a new label
// (Particles is Bokeh, Equalizer Spectrum, Stereo VU Meters, Typography Poster, Neon Horizon, AlbumWall Big Cover,
// Starfield Ripple, BlurCover Ambient) and keep their old key so a saved choice still applies.
static const std::pair<const char *, const char *> kIdleThemes[] = {
    {"GlassCard", QT_TRANSLATE_NOOP("Application", "Glass Card")},       {"BlurCover", QT_TRANSLATE_NOOP("Application", "Ambient")},  {"Aurora", QT_TRANSLATE_NOOP("Application", "Aurora")},
    {"Vinyl", QT_TRANSLATE_NOOP("Application", "Vinyl")},                {"Cassette", QT_TRANSLATE_NOOP("Application", "Cassette")},     {"Particles", QT_TRANSLATE_NOOP("Application", "Bokeh")},
    {"Equalizer", QT_TRANSLATE_NOOP("Application", "Spectrum")},        {"Stereo", QT_TRANSLATE_NOOP("Application", "VU Meters")},   {"Polaroid", QT_TRANSLATE_NOOP("Application", "Polaroid")},
    {"MinimalClock", QT_TRANSLATE_NOOP("Application", "Minimal Clock")}, {"Typography", QT_TRANSLATE_NOOP("Application", "Poster")}, {"Neon", QT_TRANSLATE_NOOP("Application", "Horizon")},
    {"AlbumWall", QT_TRANSLATE_NOOP("Application", "Big Cover")},       {"Orbit", QT_TRANSLATE_NOOP("Application", "Orbit")},        {"Starfield", QT_TRANSLATE_NOOP("Application", "Ripple")},
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
#ifdef Q_OS_LINUX
    m_mpris = new Mpris(m_player, this, this);  // media keys, playerctl, desktop widgets
    new ThemeWatcher(this);                      // follows the qt6ct color scheme live
#endif

    connect(m_auth, &AuthManager::tokenChanged, m_api, &SoundCloudApi::setToken);
    connect(m_auth, &AuthManager::tokenChanged, this, [this](const QString &token) {
        if (token.isEmpty())
            m_player->clearSession();  // the queue belongs to the account that signed out
    });
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
    const QString mode = QSettings().value(QStringLiteral("ui/colorMode"), QStringLiteral("auto")).toString();
    m_colorMode = isKnownColorMode(mode) ? mode : QStringLiteral("auto");
    const QString logo = QSettings().value(QStringLiteral("ui/logo"), QStringLiteral("auto")).toString();
    m_logoStyle = isKnownLogoStyle(logo) ? logo : QStringLiteral("auto");
    m_idleTheme = isKnownTheme(theme) ? theme : kDefaultIdleTheme;
    const QString language = QSettings().value(QStringLiteral("ui/language"), QStringLiteral("system")).toString();
    m_language = isKnownLanguage(language) ? language : QStringLiteral("system");
    m_idleAuto = QSettings().value(QStringLiteral("idle/auto"), true).toBool();
    m_idleDelay = std::clamp(QSettings().value(QStringLiteral("idle/delay"), kIdleDelayDefault).toInt(), kIdleDelayMin,
                             kIdleDelayMax);

    m_cacheLimit = std::clamp(QSettings().value(QStringLiteral("cache/limitMb"), kCacheLimitDefault).toInt(), kCacheLimitMin,
                              kCacheLimitMax);
    QmlNetworkFactory::setCacheLimit(qint64(m_cacheLimit) * 1024 * 1024);
    m_player->restoreSession();

    m_idleTimer = new QTimer(this);
    m_idleTimer->setSingleShot(true);
    connect(m_idleTimer, &QTimer::timeout, this, &Application::idleTimeout);
    connect(m_player, &PlayerController::playingChanged, this, [this] {
        const bool playing = m_player->playing();
        if (playing == std::exchange(m_wasPlaying, playing))
            return;
        if (playing)
            restartIdleTimer();  // the full delay from the moment the music starts
        else if (m_idleShownAuto)
            setIdleActive(false);
    });

    qmlRegisterSingletonInstance("ScBackend", 1, 0, "App", this);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Api", m_api);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Auth", m_auth);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Player", m_player);
    qmlRegisterSingletonInstance("ScBackend", 1, 0, "Analyser", m_analyser);
    qmlRegisterType<PagedListModel>("ScBackend", 1, 0, "PagedListModel");

    m_engine = new QQmlApplicationEngine(this);
    m_qmlNetwork = new QmlNetworkFactory;
    m_engine->setNetworkAccessManagerFactory(m_qmlNetwork);
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
    connect(m_window, &QWindow::visibilityChanged, this, &Application::restartIdleTimer);

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
    delete m_qmlNetwork;
    delete m_api;
    delete m_auth;
    webprofile::destroyNow();
}

bool Application::eventFilter(QObject *watched, QEvent *event)
{
    if (watched != m_window)
        return QObject::eventFilter(watched, event);
    switch (event->type()) {
    case QEvent::Close:
        if (m_quitting)
            break;
        event->ignore();
        m_window->hide();
        return true;
    case QEvent::MouseMove: {
        const QPoint pos = static_cast<QMouseEvent *>(event)->globalPosition().toPoint();
        if (m_activityPos.x() < 0 || (pos - m_activityPos).manhattanLength() >= kIdleMoveThreshold) {
            m_activityPos = pos;
            noteActivity();
        }
        break;
    }
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonDblClick:
    case QEvent::Wheel:
    case QEvent::KeyPress:
    case QEvent::TouchBegin:
        noteActivity();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

bool Application::systemPaletteDefault() const
{
#ifdef Q_OS_LINUX
    return qEnvironmentVariable("QT_QPA_PLATFORMTHEME").contains(QLatin1StringView("qt6ct"));
#else
    return false;
#endif
}

void Application::setColorMode(const QString &mode)
{
    if (!isKnownColorMode(mode) || mode == m_colorMode)
        return;
    m_colorMode = mode;
    QSettings().setValue(QStringLiteral("ui/colorMode"), mode);
    if (m_colorGroup) {
        for (QAction *a : m_colorGroup->actions())
            a->setChecked(a->data().toString() == mode);
    }
    emit colorModeChanged();
}

void Application::setLogoStyle(const QString &style)
{
    if (!isKnownLogoStyle(style) || style == m_logoStyle)
        return;
    m_logoStyle = style;
    QSettings().setValue(QStringLiteral("ui/logo"), style);
    emit logoStyleChanged();
}

QVariantList Application::colorModes() const
{
    return keyLabelList(kColorModes);
}

QVariantList Application::idleThemes() const
{
    return keyLabelList(kIdleThemes);
}

QVariantList Application::languages() const
{
    return keyLabelList(kLanguages);
}

void Application::setLanguage(const QString &language)
{
    if (!isKnownLanguage(language) || language == m_language)
        return;
    m_language = language;
    QSettings().setValue(QStringLiteral("ui/language"), language);
    emit languageChanged();
}

int Application::idleDelayMin() const
{
    return kIdleDelayMin;
}

int Application::idleDelayMax() const
{
    return kIdleDelayMax;
}

void Application::setIdleAuto(bool on)
{
    if (on == m_idleAuto)
        return;
    m_idleAuto = on;
    QSettings().setValue(QStringLiteral("idle/auto"), on);
    restartIdleTimer();
    emit idleAutoChanged();
}

void Application::setIdleDelay(int seconds)
{
    seconds = std::clamp(seconds, kIdleDelayMin, kIdleDelayMax);
    if (seconds == m_idleDelay)
        return;
    m_idleDelay = seconds;
    QSettings().setValue(QStringLiteral("idle/delay"), seconds);
    restartIdleTimer();
    emit idleDelayChanged();
}

int Application::cacheLimitMin() const
{
    return kCacheLimitMin;
}

int Application::cacheLimitMax() const
{
    return kCacheLimitMax;
}

void Application::setCacheLimit(int megabytes)
{
    megabytes = std::clamp(megabytes, kCacheLimitMin, kCacheLimitMax);
    if (megabytes == m_cacheLimit)
        return;
    m_cacheLimit = megabytes;
    QSettings().setValue(QStringLiteral("cache/limitMb"), megabytes);
    QmlNetworkFactory::setCacheLimit(qint64(megabytes) * 1024 * 1024);
    emit cacheLimitChanged();
}

void Application::refreshCacheSize()
{
    if (m_countingCache)
        return;
    m_countingCache = true;
    // walking a few thousand files: off the GUI thread
    QPointer<Application> self(this);
    QThreadPool::globalInstance()->start([self] {
        const qint64 bytes = diskcache::size();
        QMetaObject::invokeMethod(qApp, [self, bytes] {
            if (!self)
                return;
            self->m_countingCache = false;
            self->m_cacheSize = double(bytes);
            emit self->cacheSizeChanged();
        });
    });
}

void Application::clearCache()
{
    QmlNetworkFactory::clearCache();  // queued to the image loader's thread
    diskcache::remove(QStringLiteral("waveforms"));
    diskcache::remove(QStringLiteral("api"));
    m_cacheSize = -1;
    emit cacheSizeChanged();
    QTimer::singleShot(400, this, &Application::refreshCacheSize);
    emit toast(tr("Cache cleared"));
}

void Application::noteActivity()
{
    // over the open idle screen the QML overlay decides (a click or key closes it, moving the pointer does not)
    if (!m_idleActive)
        restartIdleTimer();
}

void Application::restartIdleTimer()
{
    if (m_idleAuto && !m_idleActive)
        m_idleTimer->start(m_idleDelay * 1000);
    else
        m_idleTimer->stop();
}

void Application::idleTimeout()
{
    // playback starting and the window being shown restart the timer, so a refused timeout just waits for those
    if (!m_idleAuto || m_idleActive || !m_player->playing() || !m_window || !m_window->isVisible()
        || m_window->visibility() == QWindow::Minimized)
        return;
    setIdleActive(true);
    m_idleShownAuto = true;
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
    m_idleShownAuto = false;
    m_analyser->setActive(on);  // the analyser only runs while the screen is open
    restartIdleTimer();
    emit idleActiveChanged();
}

void Application::showIdle()
{
    if (m_window && (!m_window->isVisible() || m_window->visibility() == QWindow::Minimized))
        raiseWindow();
    setIdleActive(true);
}

void Application::openSettings()
{
    raiseWindow();
    setIdleActive(false);
    emit settingsRequested();
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
    emit toast(tr("Link copied"));
    if (m_tray && (!m_window || !m_window->isVisible()))
        m_tray->showMessage(QStringLiteral("SoundCloud Desktop"), tr("Link copied to clipboard: %1").arg(url),
                            QSystemTrayIcon::Information, 2000);
}

void Application::copyLink(const QString &url)
{
    if (url.isEmpty())
        return;
    QGuiApplication::clipboard()->setText(url);
    emit toast(tr("Link copied"));
}

void Application::openExternal(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

void Application::openSoundCloudUrl(const QString &url)
{
    const QUrl u(url.trimmed());
    if (!u.host().endsWith(QLatin1StringView("soundcloud.com")) && u.host() != QLatin1StringView("on.soundcloud.com")) {
        emit toast(tr("Not a SoundCloud link"));
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
    }, [this](int, const QString &err) { emit toast(tr("Could not open the link (%1)").arg(err)); });
}

bool Application::isGone(const QString &url) const
{
    return QmlNetworkFactory::isGone(url);
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
    // the bundled icon directly, not QIcon::fromTheme: a themed "soundcloud-rpc" from another install (e.g. an
    // older package) would otherwise show a different icon in the tray than the window and the UI use
    QIcon icon(QStringLiteral(":/soundcloud.png"));
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("audio-player"), QIcon::fromTheme(QStringLiteral("audio-x-generic")));
    m_tray->setIcon(icon);
    m_tray->setToolTip(QStringLiteral("SoundCloud Desktop"));

    m_trayMenu = new QMenu();
    m_trayMenu->addAction(tr("Play / Pause"), m_player, &PlayerController::togglePlay);
    m_trayMenu->addAction(tr("Next"), m_player, &PlayerController::next);
    m_trayMenu->addAction(tr("Previous"), m_player, &PlayerController::previous);
    m_trayMenu->addAction(tr("Copy Track Link"), this, &Application::copyTrackLink);
    m_trayMenu->addAction(tr("Show / Hide Window"), this, &Application::toggleWindow);
    m_trayMenu->addAction(tr("Settings…"), this, &Application::openSettings);
    m_trayMenu->addSeparator();
    createAppearanceMenu(m_trayMenu);
    createIdleMenu(m_trayMenu);
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(tr("Sign Out"), m_auth, &AuthManager::signOut);
    m_trayMenu->addAction(tr("Quit"), this, &Application::quit);

    m_tray->setContextMenu(m_trayMenu);
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger)
            toggleWindow();
    });
    connect(this, &QObject::destroyed, m_trayMenu, &QObject::deleteLater);
    m_tray->show();
}

void Application::createAppearanceMenu(QMenu *menu)
{
    QMenu *appearance = menu->addMenu(tr("Appearance"));
    m_colorGroup = new QActionGroup(this);
    for (const auto &[key, text] : kColorModes) {
        QAction *a = appearance->addAction(::label(text));
        a->setCheckable(true);
        a->setData(QLatin1StringView(key));
        a->setChecked(m_colorMode == QLatin1StringView(key));
        m_colorGroup->addAction(a);
        connect(a, &QAction::triggered, this, [this, k = QString::fromLatin1(key)] { setColorMode(k); });
    }
}

void Application::createIdleMenu(QMenu *menu)
{
    QMenu *idle = menu->addMenu(tr("Idle Screen"));
    idle->addAction(tr("Show Idle Screen"), this, &Application::showIdle);
    idle->addSeparator();
    m_themeGroup = new QActionGroup(this);
    for (const auto &[key, text] : kIdleThemes) {
        QAction *a = idle->addAction(::label(text));
        a->setCheckable(true);
        a->setData(QLatin1StringView(key));
        a->setChecked(m_idleTheme == QLatin1StringView(key));
        m_themeGroup->addAction(a);
        connect(a, &QAction::triggered, this, [this, k = QString::fromLatin1(key)] { setIdleTheme(k); });
    }
}
