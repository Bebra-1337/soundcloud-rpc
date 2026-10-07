#pragma once

#include <QObject>
#include <QPoint>
#include <QPointer>
#include <QVariantList>

class QQmlApplicationEngine;
class QQuickWindow;
class QSystemTrayIcon;
class QMenu;
class QActionGroup;
class QTimer;
class QmlNetworkFactory;
class SoundCloudApi;
class AuthManager;
class PlayerController;
class AudioAnalyser;
class DiscordPresence;
#ifdef Q_OS_LINUX
class Mpris;
#endif

// Wires the backend (API, sign-in, player, analyser, Discord, MPRIS) to the QML window and the tray, and owns
// window lifecycle: closing hides to the tray, only quit() exits. Exposed to QML as the `App` singleton.
class Application : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString idleTheme READ idleTheme WRITE setIdleTheme NOTIFY idleThemeChanged)
    Q_PROPERTY(QVariantList idleThemes READ idleThemes CONSTANT)
    Q_PROPERTY(bool idleAuto READ idleAuto WRITE setIdleAuto NOTIFY idleAutoChanged)
    Q_PROPERTY(int idleDelay READ idleDelay WRITE setIdleDelay NOTIFY idleDelayChanged)
    Q_PROPERTY(int idleDelayMin READ idleDelayMin CONSTANT)
    Q_PROPERTY(int idleDelayMax READ idleDelayMax CONSTANT)
    Q_PROPERTY(QString colorMode READ colorMode WRITE setColorMode NOTIFY colorModeChanged)
    Q_PROPERTY(QVariantList colorModes READ colorModes CONSTANT)
    Q_PROPERTY(bool systemPaletteDefault READ systemPaletteDefault CONSTANT)
    Q_PROPERTY(bool idleActive READ idleActive WRITE setIdleActive NOTIFY idleActiveChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)

public:
    Application(bool minimized, const QStringList &urls, QObject *parent = nullptr);
    ~Application() override;

    QString idleTheme() const { return m_idleTheme; }
    void setIdleTheme(const QString &key);
    QVariantList idleThemes() const;
    // the idle screen opens by itself after this many seconds without input while music plays
    bool idleAuto() const { return m_idleAuto; }
    void setIdleAuto(bool on);
    int idleDelay() const { return m_idleDelay; }
    void setIdleDelay(int seconds);
    int idleDelayMin() const;
    int idleDelayMax() const;
    // "auto" | "system" | "dark" | "light": which colors the main UI uses (Style.qml)
    QString colorMode() const { return m_colorMode; }
    void setColorMode(const QString &mode);
    QVariantList colorModes() const;
    // true where "auto" follows the desktop's Qt palette (Linux with qt6ct); elsewhere "auto" is the brand dark theme
    bool systemPaletteDefault() const;
    bool idleActive() const { return m_idleActive; }
    void setIdleActive(bool on);
    // "system" | "en" | "ru"; only stored for now, the interface is not translated yet
    QString language() const { return m_language; }
    void setLanguage(const QString &language);
    QVariantList languages() const;

    Q_INVOKABLE void raiseWindow();
    Q_INVOKABLE void toggleWindow();
    Q_INVOKABLE void showIdle();
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void copyTrackLink();
    Q_INVOKABLE void copyLink(const QString &url);
    Q_INVOKABLE void openExternal(const QString &url);
    // a soundcloud.com link (pasted, from the command line or MPRIS OpenUri): play or open it
    Q_INVOKABLE void openSoundCloudUrl(const QString &url);
    Q_INVOKABLE void quit();
    // the server answered this URL with a 4xx: the image doesn't exist (ArtImage)
    Q_INVOKABLE bool isGone(const QString &url) const;

    // Navigation requests from anywhere in the UI (handlers, popups, delegates), handled by Main.qml.
    Q_INVOKABLE void openItem(const QVariantMap &item) { emit openItemRequested(item); }
    Q_INVOKABLE void playCollection(const QVariantMap &item) { emit playCollectionRequested(item); }
    Q_INVOKABLE void showMenu(const QVariantMap &item) { emit menuRequested(item); }

signals:
    void idleThemeChanged();
    void colorModeChanged();
    void idleActiveChanged();
    void idleAutoChanged();
    void idleDelayChanged();
    void languageChanged();
    void settingsRequested();
    void openItemRequested(const QVariantMap &item);
    void playCollectionRequested(const QVariantMap &item);
    void menuRequested(const QVariantMap &item);
    void toast(const QString &text);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void createTray();
    void createIdleMenu(QMenu *menu);
    void createAppearanceMenu(QMenu *menu);
    void noteActivity();
    void restartIdleTimer();
    void idleTimeout();

    SoundCloudApi *m_api;
    AuthManager *m_auth;
    PlayerController *m_player;
    AudioAnalyser *m_analyser;
    DiscordPresence *m_discord;
#ifdef Q_OS_LINUX
    Mpris *m_mpris;
#endif
    QQmlApplicationEngine *m_engine;
    QmlNetworkFactory *m_qmlNetwork;  // must outlive the engine
    QPointer<QQuickWindow> m_window;
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_trayMenu = nullptr;
    QActionGroup *m_themeGroup = nullptr;
    QActionGroup *m_colorGroup = nullptr;

    QString m_colorMode;
    QString m_idleTheme;
    QString m_language;
    bool m_idleActive = false;
    bool m_idleAuto = true;
    bool m_idleShownAuto = false;  // opened by the timer: closes again when the music stops
    bool m_wasPlaying = false;
    int m_idleDelay = 30;
    QTimer *m_idleTimer = nullptr;
    QPoint m_activityPos{-1, -1};  // pointer position at the last input, for the movement threshold
    bool m_quitting = false;
    QStringList m_pendingUrls;
};
