#pragma once

#include <QElapsedTimer>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QStringList>
#include <optional>

class QLocalSocket;
class QTimer;

struct DiscordActivity {
    QString details;
    QString state;
    QString largeImage;
    QString largeText;
    QString smallImage;
    QString smallText;
    QString buttonLabel;
    QString buttonUrl;
    qint64 start = 0;  // unix milliseconds, 0 = none
    qint64 end = 0;

    // Equal enough not to resend: timestamps may differ by up to 1.5 s (measurement noise); a seek, a skip or
    // a buffering stall moves them more and is sent.
    bool same(const DiscordActivity &other) const;
    QJsonObject toJson() const;
};

// Discord's local RPC (the IPC socket discord-ipc-N): framed JSON, opcode + length (little endian) + payload.
// The client publishes a *desired* activity; this converges to the latest one: it dedupes (DiscordActivity::same),
// waits 0.25 s after the last real change so transient states collapse, rate limits with a sliding window of
// 4 updates per 20 s (Discord allows about 5; a throttled update is delayed, never dropped), reconnects every
// 5 s and re-sends after a reconnect. A payload Discord rejects does not tear the connection down.
class DiscordIpc : public QObject
{
    Q_OBJECT
public:
    explicit DiscordIpc(const QString &clientId, QObject *parent = nullptr);
    ~DiscordIpc() override;

    void setActivity(const DiscordActivity &activity);

private:
    enum State { Disconnected, Connecting, Handshaking, Ready };

    void connectNext();
    void scheduleReconnect();
    void onConnected();
    void onReadyRead();
    void onLost();
    void handleFrame(quint32 op, const QJsonObject &payload);
    void writeFrame(quint32 op, const QJsonObject &payload);
    void process();

    QString m_clientId;
    QLocalSocket *m_socket;
    QTimer *m_wake;
    QTimer *m_reconnect;
    State m_state = Disconnected;
    QStringList m_candidates;
    QByteArray m_buffer;
    bool m_waitingLogged = false;

    QElapsedTimer m_clock;
    std::optional<DiscordActivity> m_desired;
    std::optional<DiscordActivity> m_lastSent;
    bool m_dirty = false;
    qint64 m_changedAt = 0;
    QList<qint64> m_sentTimes;
};
