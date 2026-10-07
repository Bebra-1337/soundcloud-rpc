#include "app/ThemeWatcher.h"

#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

ThemeWatcher::ThemeWatcher(QObject *parent)
    : QObject(parent), m_watcher(new QFileSystemWatcher(this)), m_debounce(new QTimer(this))
{
    if (!qEnvironmentVariable("QT_QPA_PLATFORMTHEME").contains(QLatin1StringView("qt6ct")))
        return;  // colors come from somewhere else (or Qt's defaults): nothing to follow
    m_configPath = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/qt6ct/qt6ct.conf");

    // writers often replace files (write + rename) or touch them several times in a row
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(250);
    connect(m_debounce, &QTimer::timeout, this, [this] {
        rewatch();
        apply();
    });
    connect(m_watcher, &QFileSystemWatcher::fileChanged, m_debounce, qOverload<>(&QTimer::start));
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, m_debounce, qOverload<>(&QTimer::start));
    rewatch();
}

void ThemeWatcher::rewatch()
{
    QSettings conf(m_configPath, QSettings::IniFormat);
    conf.sync();  // QSettings caches files per process: pick up what changed on disk
    m_schemePath = conf.value(QStringLiteral("Appearance/custom_palette")).toBool()
                       ? conf.value(QStringLiteral("Appearance/color_scheme_path")).toString()
                       : QString();

    // a replaced file drops out of the watch list, so the directories are watched too
    QStringList paths{m_configPath, QFileInfo(m_configPath).absolutePath()};
    if (!m_schemePath.isEmpty())
        paths << m_schemePath << QFileInfo(m_schemePath).absolutePath();
    QStringList existing;
    for (const QString &p : std::as_const(paths)) {
        if (QFileInfo::exists(p) && !existing.contains(p))
            existing << p;
    }
    const QStringList watched = m_watcher->files() + m_watcher->directories();
    if (!watched.isEmpty())
        m_watcher->removePaths(watched);
    if (!existing.isEmpty())
        m_watcher->addPaths(existing);
}

// qt6ct color scheme: [ColorScheme] active_colors / inactive_colors / disabled_colors, each a comma separated
// list of colors in QPalette::ColorRole order (WindowText, Button, Light, ..., PlaceholderText, Accent).
void ThemeWatcher::apply()
{
    if (m_schemePath.isEmpty())
        return;
    QSettings scheme(m_schemePath, QSettings::IniFormat);
    scheme.sync();
    const std::pair<const char *, QPalette::ColorGroup> groups[] = {
        {"ColorScheme/active_colors", QPalette::Active},
        {"ColorScheme/inactive_colors", QPalette::Inactive},
        {"ColorScheme/disabled_colors", QPalette::Disabled},
    };
    QPalette palette = QGuiApplication::palette();
    bool any = false;
    for (const auto &[key, group] : groups) {
        const QStringList colors = scheme.value(QLatin1StringView(key)).toStringList();
        for (int role = 0; role < colors.size() && role < QPalette::NColorRoles; ++role) {
            const QColor c = QColor::fromString(colors.at(role).trimmed());
            if (c.isValid() && role != QPalette::NoRole) {
                palette.setColor(group, QPalette::ColorRole(role), c);
                any = true;
            }
        }
    }
    if (any && palette != QGuiApplication::palette()) {
        qInfo() << "System colors changed, applying" << QFileInfo(m_schemePath).fileName();
        QGuiApplication::setPalette(palette);
    }
}
