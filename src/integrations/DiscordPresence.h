#pragma once

#include <QObject>

class DiscordIpc;
class PlayerController;
class QTimer;

// Discord Rich Presence for the player: "Listening to <title> by <artist>" with the cover, exact timestamps
// from the player and a "Listen on SoundCloud" button; "Paused" / "Exploring SoundCloud" otherwise.
class DiscordPresence : public QObject
{
    Q_OBJECT
public:
    explicit DiscordPresence(PlayerController *player, QObject *parent = nullptr);

    // Discord rejects details/state shorter than 2 or longer than 128 bytes; a rejected payload used to look
    // like a dropped connection.
    static QString cleanText(const QString &text);

private:
    void update();

    PlayerController *m_player;
    DiscordIpc *m_ipc;
    QTimer *m_refresh;
};
