#pragma once

#include <QObject>
#include <QString>

class QFileSystemWatcher;
class QTimer;

// Live system colors. The qt6ct platform theme reads its color scheme once at startup, so when the desktop
// changes it (Noctalia rewrites ~/.config/qt6ct/colors/noctalia.conf on every theme switch) running apps keep
// the old palette. This watches qt6ct.conf and the scheme file it points to and, on a change, loads the scheme
// itself and sets it as the application palette; SystemPalette in QML (Style.qml) follows.
class ThemeWatcher : public QObject
{
    Q_OBJECT
public:
    explicit ThemeWatcher(QObject *parent = nullptr);

private:
    void rewatch();
    void apply();

    QFileSystemWatcher *m_watcher;
    QTimer *m_debounce;
    QString m_configPath;
    QString m_schemePath;
};
