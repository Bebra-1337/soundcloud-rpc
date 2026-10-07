#pragma once

class QWebEngineProfile;

// The one browser profile of the app (~/.config/soundcloud_rpc/storage, the user's soundcloud.com session),
// shared by the sign-in window (AuthManager) and the hidden page for anti-bot-protected requests (WebSession).
// Chromium locks the storage directory, so two profile instances on it at once fail; users acquire the
// shared instance and release it when done, and it is destroyed when the last one lets go. Pages must be
// deleted before releasing.
namespace webprofile {

QWebEngineProfile *acquire();
void release();
// at exit, when there is no event loop left for deleteLater
void destroyNow();

} // namespace webprofile
