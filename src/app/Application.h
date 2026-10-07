#pragma once

#include <QObject>
#include <QPointer>
#include <QVariantList>

class QQmlApplicationEngine;
class QQuickWindow;
class QSystemTrayIcon;
class QMenu;
class QActionGroup;
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
    Q_PROPERTY(bool idleActive READ idleActive WRITE setIdleActive NOTIFY idleActiveChanged)

public:
    Application(bool minimized, const QStringList &urls, QObject *parent = nullptr);
    ~Application() override;

    QString idleTheme() const { return m_idleTheme; }
    void setIdleTheme(const QString &key);
    QVariantList idleThemes() const;
    bool idleActive() const { return m_idleActive; }
    void setIdleActive(bool on);

    Q_INVOKABLE void raiseWindow();
    Q_INVOKABLE void toggleWindow();
    Q_INVOKABLE void showIdle();
    Q_INVOKABLE void copyTrackLink();
    Q_INVOKABLE void copyLink(const QString &url);
    Q_INVOKABLE void openExternal(const QString &url);
    // a soundcloud.com link (pasted, from the command line or MPRIS OpenUri): play or open it
    Q_INVOKABLE void openSoundCloudUrl(const QString &url);
    Q_INVOKABLE void quit();

    // Navigation requests from anywhere in the UI (handlers, popups, delegates), handled by Main.qml.
    Q_INVOKABLE void openItem(const QVariantMap &item) { emit openItemRequested(item); }
    Q_INVOKABLE void playCollection(const QVariantMap &item) { emit playCollectionRequested(item); }
    Q_INVOKABLE void showMenu(const QVariantMap &item) { emit menuRequested(item); }

signals:
    void idleThemeChanged();
    void idleActiveChanged();
    void openItemRequested(const QVariantMap &item);
    void playCollectionRequested(const QVariantMap &item);
    void menuRequested(const QVariantMap &item);
    void toast(const QString &text);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void createTray();
    void createIdleMenu(QMenu *menu);

    SoundCloudApi *m_api;
    AuthManager *m_auth;
    PlayerController *m_player;
    AudioAnalyser *m_analyser;
    DiscordPresence *m_discord;
#ifdef Q_OS_LINUX
    Mpris *m_mpris;
#endif
    QQmlApplicationEngine *m_engine;
    QPointer<QQuickWindow> m_window;
    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_trayMenu = nullptr;
    QActionGroup *m_themeGroup = nullptr;

    QString m_idleTheme;
    bool m_idleActive = false;
    bool m_quitting = false;
    QStringList m_pendingUrls;
};
