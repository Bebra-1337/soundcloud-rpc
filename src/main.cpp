#include "app/Application.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QIcon>
#include <QLoggingCategory>

int main(int argc, char *argv[])
{
    // the sign-in window (QtWebEngine) shares GL contexts with Qt Quick
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    // Qt Multimedia probes for PipeWire before falling back to PulseAudio and says so on every start;
    // QT_LOGGING_RULES still overrides this.
    QLoggingCategory::setFilterRules(QStringLiteral("qt.multimedia.symbolsresolver=false"));

    // Chromium (sign-in window, anti-bot fallback page) logs every failed request of the website's third-party
    // scripts at ERROR level; keep only fatal ones unless the caller asked for something else
    if (!qEnvironmentVariable("QTWEBENGINE_CHROMIUM_FLAGS").contains(QLatin1StringView("--log-level")))
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", (qgetenv("QTWEBENGINE_CHROMIUM_FLAGS") + " --log-level=3").trimmed());

    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("soundcloud-rpc"));
    app.setApplicationDisplayName(QStringLiteral("SoundCloud Desktop"));
    app.setApplicationVersion(QStringLiteral(PROJECT_VERSION));
    app.setOrganizationName(QStringLiteral("SoundCloud"));  // QSettings: ~/.config/SoundCloud/soundcloud-rpc.conf
    app.setDesktopFileName(QStringLiteral("soundcloud-rpc"));  // Wayland app_id, matched by window rules
    app.setWindowIcon(QIcon(QStringLiteral(":/soundcloud.png")));
    app.setQuitOnLastWindowClosed(false);  // closing the window hides it to the tray

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("SoundCloud Desktop Player with Discord RPC & MPRIS"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({{QStringLiteral("minimized"), QStringLiteral("tray"), QStringLiteral("m"), QStringLiteral("t")},
                      QStringLiteral("Start application minimized to system tray")});
    parser.addPositionalArgument(QStringLiteral("url"), QStringLiteral("SoundCloud links to open"), QStringLiteral("[url...]"));
    parser.process(app);

    Application client(parser.isSet(QStringLiteral("minimized")), parser.positionalArguments());
    return app.exec();
}
