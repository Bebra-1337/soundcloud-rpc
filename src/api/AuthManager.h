#pragma once

#include <QObject>
#include <QPointer>

class QWebEngineProfile;
class QWebEngineView;
class QNetworkCookie;
class QTimer;

// Signs the user in with their own SoundCloud account. The only place that still uses a browser engine:
// soundcloud.com's sign-in page runs in a QtWebEngine window with the same persistent profile as the old
// web-wrapper client (~/.config/soundcloud_rpc/storage), and the session's oauth_token cookie is taken from
// the cookie store. When that profile is already signed in the window never shows. The token is kept in
// ~/.config/soundcloud_rpc/token (mode 0600); Chromium is not started again until the token is rejected.
class AuthManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY tokenChanged)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY signingInChanged)

public:
    explicit AuthManager(QObject *parent = nullptr);
    ~AuthManager() override;

    QString token() const { return m_token; }
    bool signedIn() const { return !m_token.isEmpty(); }
    bool signingIn() const { return m_profile != nullptr; }

    // load the saved token, or start signing in
    void start();

    Q_INVOKABLE void signIn();
    Q_INVOKABLE void signOut();
    // the API rejected this token (expired): forget it and sign in again
    void rejectToken(const QString &token);

signals:
    void tokenChanged(const QString &token);
    void signingInChanged();

private:
    void createProfile();
    void onCookie(const QNetworkCookie &cookie);
    void showWindow();
    void accept(const QString &token);
    void teardown();
    void saveToken(const QString &token);

    QString m_token;
    QString m_rejected;
    bool m_clearCookies = false;
    QWebEngineProfile *m_profile = nullptr;
    QPointer<QWebEngineView> m_view;
    QTimer *m_waitForCookie = nullptr;
};
