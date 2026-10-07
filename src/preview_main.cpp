// Standalone gallery of the idle-screen themes with fake data:
// soundcloud-rpc-preview [--shots DIR] [--cover FILE] [--size WxH] [--fixed] [--only Theme,Theme] [--music] [--fps]
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QUrl>
#include <cstdio>

static QString option(const QStringList &args, const QString &name, const QString &fallback = {})
{
    const qsizetype i = args.indexOf(name);
    return i >= 0 && i + 1 < args.size() ? args.at(i + 1) : fallback;
}

int main(int argc, char *argv[])
{
    // QML console.log / warnings straight to stdout, unbuffered
    qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &msg) {
        std::printf("%s\n", qPrintable(msg));
        std::fflush(stdout);
    });
    QSurfaceFormat fmt;
    fmt.setSamples(4);  // same multisampling and color depth as the client's window
    fmt.setRedBufferSize(8);
    fmt.setGreenBufferSize(8);
    fmt.setBlueBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments();
    const QStringList size = option(args, QStringLiteral("--size"), QStringLiteral("1431x500")).split(u'x');
    const int width = size.value(0).toInt();
    const int height = size.value(1).toInt();

    QVariantMap props{
        {QStringLiteral("shotsDir"), option(args, QStringLiteral("--shots"))},
        {QStringLiteral("width"), width},
        {QStringLiteral("height"), height},
        {QStringLiteral("themeFilter"), option(args, QStringLiteral("--only"))},
        {QStringLiteral("fakeAudio"), args.contains(QStringLiteral("--music"))},
        {QStringLiteral("showFps"), args.contains(QStringLiteral("--fps"))},
    };
    const QString cover = option(args, QStringLiteral("--cover"));
    if (!cover.isEmpty())
        props[QStringLiteral("coverUrl")] = QUrl::fromLocalFile(cover);

    QQmlApplicationEngine engine;
    engine.setInitialProperties(props);
    engine.loadFromModule("SoundCloudRpc.Idle", "Preview");
    if (engine.rootObjects().isEmpty())
        return 1;
    if (args.contains(QStringLiteral("--fixed"))) {
        // a fixed-size window is floated by tiling compositors, so it renders at exactly this size
        auto *win = qobject_cast<QWindow *>(engine.rootObjects().constFirst());
        win->setMinimumSize({width, height});
        win->setMaximumSize({width, height});
    }
    return app.exec();
}
