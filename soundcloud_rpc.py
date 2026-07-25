import sys
import json
import time
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from PySide6.QtCore import QUrl, QTimer, Slot, Property, ClassInfo
from PySide6.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QSystemTrayIcon, QMenu
from PySide6.QtGui import QIcon, QAction, QDesktopServices
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEnginePage, QWebEngineUrlRequestInterceptor, QWebEngineScript
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtDBus import QDBusAbstractAdaptor, QDBusConnection
from pypresence import Presence, ActivityType

# D-Bus MPRIS Interface Adaptors
@ClassInfo({
    "D-Bus Interface": "org.mpris.MediaPlayer2",
    "D-Bus Introspection": """
    <interface name="org.mpris.MediaPlayer2">
        <method name="Raise"/>
        <method name="Quit"/>
        <property name="CanQuit" type="b" access="read"/>
        <property name="CanRaise" type="b" access="read"/>
        <property name="HasTrackList" type="b" access="read"/>
        <property name="Identity" type="s" access="read"/>
        <property name="SupportedUriSchemes" type="as" access="read"/>
        <property name="SupportedMimeTypes" type="as" access="read"/>
    </interface>
    """
})
class MprisAdaptor(QDBusAbstractAdaptor):
    def __init__(self, parent):
        super().__init__(parent)

    @Slot()
    def Raise(self):
        self.parent().raise_window()

    @Slot()
    def Quit(self):
        self.parent().quit_app()

    CanQuit = Property(bool, fget=lambda self: True)
    CanRaise = Property(bool, fget=lambda self: True)
    HasTrackList = Property(bool, fget=lambda self: False)
    Identity = Property(str, fget=lambda self: "SoundCloud Desktop")
    SupportedUriSchemes = Property(list, fget=lambda self: [])
    SupportedMimeTypes = Property(list, fget=lambda self: [])


@ClassInfo({
    "D-Bus Interface": "org.mpris.MediaPlayer2.Player",
    "D-Bus Introspection": """
    <interface name="org.mpris.MediaPlayer2.Player">
        <method name="PlayPause"/>
        <method name="Next"/>
        <method name="Previous"/>
        <method name="Play"/>
        <method name="Pause"/>
        <property name="PlaybackStatus" type="s" access="read"/>
        <property name="CanPlay" type="b" access="read"/>
        <property name="CanPause" type="b" access="read"/>
        <property name="CanGoNext" type="b" access="read"/>
        <property name="CanGoPrevious" type="b" access="read"/>
        <property name="CanControl" type="b" access="read"/>
    </interface>
    """
})
class MprisPlayerAdaptor(QDBusAbstractAdaptor):
    def __init__(self, parent):
        super().__init__(parent)

    @Slot()
    def PlayPause(self):
        self.parent().trigger_play_pause()

    @Slot()
    def Next(self):
        self.parent().trigger_next()

    @Slot()
    def Previous(self):
        self.parent().trigger_prev()

    @Slot()
    def Play(self):
        self.parent().trigger_play()

    @Slot()
    def Pause(self):
        self.parent().trigger_pause()

    PlaybackStatus = Property(str, fget=lambda self: self.parent().playback_status)
    CanPlay = Property(bool, fget=lambda self: True)
    CanPause = Property(bool, fget=lambda self: True)
    CanGoNext = Property(bool, fget=lambda self: True)
    CanGoPrevious = Property(bool, fget=lambda self: True)
    CanControl = Property(bool, fget=lambda self: True)


# AdBlock Interceptor to block audio & visual ads
class AdBlockInterceptor(QWebEngineUrlRequestInterceptor):
    def interceptRequest(self, info):
        url = info.requestUrl().toString().lower()

        # Inject standard Chrome Client Hints headers to bypass Cloudflare/DataDome
        info.setHttpHeader(b"User-Agent", b"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36")
        info.setHttpHeader(b"Sec-Ch-Ua", b'"Chromium";v="136", "Not(A:Brand";v="24", "Google Chrome";v="136"')
        info.setHttpHeader(b"Sec-Ch-Ua-Mobile", b"?0")
        info.setHttpHeader(b"Sec-Ch-Ua-Platform", b'"Linux"')

        ad_keywords = [
            "doubleclick",
            "google-analytics",
            "scorecardresearch",
            "quantserve",
            "adzerk",
            "adnxs",
            "pagead",
            "adsystem",
            "secure-pubads",
            "googleads",
            "g.doubleclick.net",
            "googlesyndication",
            "adservice"
        ]
        if any(keyword in url for keyword in ad_keywords):
            info.block(True)


def resolve_target_url(url: QUrl) -> QUrl:
    url_str = url.toString()
    host = url.host().lower()
    if host in ("gate.sc", "exit.sc", "www.gate.sc", "www.exit.sc") or "soundcloud.com/exit" in url_str:
        try:
            parsed = urlparse(url_str)
            qs = parse_qs(parsed.query)
            if "url" in qs and qs["url"]:
                return QUrl(qs["url"][0])
        except Exception:
            pass
    return url


def is_internal_soundcloud_host(host: str) -> bool:
    if not host:
        return True
    host = host.lower()
    if host in ("gate.sc", "exit.sc", "www.gate.sc", "www.exit.sc"):
        return False
    if host == "soundcloud.com" or host.endswith(".soundcloud.com"):
        return True
    return False


# Temporary WebPage class to handle target="_blank" links or new window requests
class SoundCloudExternalPage(QWebEnginePage):
    def __init__(self, profile, parent=None):
        super().__init__(profile, parent)
        self.handled = False

    def acceptNavigationRequest(self, url, navigation_type, is_main_frame):
        url_str = url.toString()
        if url.isValid() and url_str not in ("about:blank", ""):
            if not self.handled:
                self.handled = True
                target_url = resolve_target_url(url)
                print(f"[External Link] Opening in default browser: {target_url.toString()}")
                QDesktopServices.openUrl(target_url)
                self.deleteLater()
            return False
        return super().acceptNavigationRequest(url, navigation_type, is_main_frame)


# Custom Web Page to intercept JavaScript console logs and handle external link navigation
class SoundCloudWebPage(QWebEnginePage):
    def __init__(self, profile, parent=None):
        super().__init__(profile, parent)

    def createWindow(self, type):
        return SoundCloudExternalPage(self.profile(), self.parent())

    def acceptNavigationRequest(self, url, navigation_type, is_main_frame):
        if navigation_type == QWebEnginePage.NavigationType.NavigationTypeLinkClicked:
            target_url = resolve_target_url(url)
            host = target_url.host().lower()
            if not is_internal_soundcloud_host(host):
                print(f"[External Link Clicked] Opening in default browser: {target_url.toString()}")
                QDesktopServices.openUrl(target_url)
                return False
        return super().acceptNavigationRequest(url, navigation_type, is_main_frame)

    def javaScriptConsoleMessage(self, level, message, lineNumber, sourceID):
        if message.startswith("SOUNDCLOUD_RPC_UPDATE:"):
            payload = message[len("SOUNDCLOUD_RPC_UPDATE:"):]
            self.parent().handle_js_result(payload)
        elif message.startswith("SOUNDCLOUD_RPC_ERROR:"):
            print("JS Observer Error:", message)
        else:
            # Let other logs pass through
            super().javaScriptConsoleMessage(level, message, lineNumber, sourceID)


class SoundCloudClient(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("SoundCloud Desktop")
        self.resize(1280, 720)

        self.is_playing = False
        self.playback_status = "Stopped"

        # Create persistent storage folder
        storage_path = Path.home() / ".config" / "soundcloud_rpc" / "storage"
        storage_path.mkdir(parents=True, exist_ok=True)

        # Set persistent storage and cookies path so login persists
        self.profile = QWebEngineProfile("soundcloud_profile", self)
        self.profile.setPersistentStoragePath(str(storage_path))
        self.profile.setPersistentCookiesPolicy(QWebEngineProfile.PersistentCookiesPolicy.ForcePersistentCookies)

        # Dynamically clean User-Agent by removing "QtWebEngine/X.Y.Z" to pass Cloudflare/DataDome bot checks
        default_ua = self.profile.httpUserAgent()
        clean_ua = [part for part in default_ua.split(" ") if not part.startswith("QtWebEngine")]
        clean_ua_str = " ".join(clean_ua)
        self.profile.setHttpUserAgent(clean_ua_str)
        print("Using clean User-Agent:", clean_ua_str)

        # Create and register the Stealth Script to bypass Cloudflare/DataDome bot checks
        stealth_script = QWebEngineScript()
        stealth_script.setName("stealth")
        stealth_script.setSourceCode("""
            // 1. Hide webdriver flag
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });

            // 2. Mock chrome object (many anti-bot scripts expect window.chrome)
            if (!window.chrome) {
                window.chrome = {
                    runtime: {},
                    loadTimes: function() {},
                    csi: function() {},
                    app: {}
                };
            }

            // 3. Mock languages (often scrutinized)
            Object.defineProperty(navigator, 'languages', {
                get: () => ['ru-RU', 'ru', 'en-US', 'en']
            });

            // 4. Mock plugins (webviews have 0 plugins, which is a major red flag)
            if (!navigator.plugins || navigator.plugins.length === 0) {
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [
                        { name: 'PDF Viewer', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
                        { name: 'Chrome PDF Viewer', filename: 'mhjfbgofeelibecpbjeoegjhbcgbbolf', description: 'Google Chrome PDF Viewer' }
                    ]
                });
            }
        """)
        stealth_script.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentCreation)
        stealth_script.setWorldId(QWebEngineScript.ScriptWorldId.MainWorld)
        stealth_script.setRunsOnSubFrames(True)
        self.profile.scripts().insert(stealth_script)

        # Create and register the CSS AdBlock Script (visual only) to avoid network-level integrity blocks
        adblock_css_script = QWebEngineScript()
        adblock_css_script.setName("adblock_css")
        adblock_css_script.setSourceCode("""
            (function() {
                var style = document.createElement('style');
                style.textContent = `
                    .promotion, .audiblePromotion, .adBox, [class*="ad-"], [id*="ad-"], div[id^="google_ads_"] {
                        display: none !important;
                    }
                `;
                document.documentElement.appendChild(style);
            })();
        """)
        adblock_css_script.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentReady)
        adblock_css_script.setWorldId(QWebEngineScript.ScriptWorldId.MainWorld)
        adblock_css_script.setRunsOnSubFrames(True)
        self.profile.scripts().insert(adblock_css_script)

        # Register AdBlocker & Header Interceptor
        self.ad_interceptor = AdBlockInterceptor()
        self.profile.setUrlRequestInterceptor(self.ad_interceptor)

        # Webview with custom page using the profile
        self.view = QWebEngineView()
        self.web_page = SoundCloudWebPage(self.profile, self)
        self.view.setPage(self.web_page)
        self.view.setUrl(QUrl("https://soundcloud.com/discover"))

        # Re-inject observer when load finishes
        self.view.loadFinished.connect(self.inject_observer)

        # Layout
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.view)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        # Discord RPC
        self.client_id = "1289606421368799345"  # SoundCloud assets
        self.RPC = None
        self.rpc_connected = False
        self.last_track = None
        self.last_state = None
        self.last_start_time = None
        self.last_cover = None

        self.connect_discord()

        # MPRIS D-Bus Server Setup
        self.root_mpris = MprisAdaptor(self)
        self.player_mpris = MprisPlayerAdaptor(self)
        conn = QDBusConnection.sessionBus()
        if not conn.registerService("org.mpris.MediaPlayer2.soundcloud_rpc"):
            print("Failed to register D-Bus service org.mpris.MediaPlayer2.soundcloud_rpc")
        if not conn.registerObject("/org/mpris/MediaPlayer2", self):
            print("Failed to register D-Bus object /org/mpris/MediaPlayer2")

        # System Tray setup
        self.really_quit = False
        self.create_tray()

        # Passive observer script definitions
        self.observer_js_code = r"""
        (() => {
            if (window.soundcloud_rpc_observer_set) return;
            window.soundcloud_rpc_observer_set = true;
            
            console.log("SOUNDCLOUD_RPC: Observer injecting...");
            
            function sendUpdate() {
                try {
                    var playbtn = document.querySelector(".playControls__elements .playControl");
                    var currentsongtitle = document.querySelector(".playbackSoundBadge__title");
                    var currentartist = document.querySelector(".playbackSoundBadge__lightLink");
                    
                    if (!playbtn || !currentsongtitle || !currentartist) {
                        console.log("SOUNDCLOUD_RPC_UPDATE:" + JSON.stringify({
                            debug: true,
                            has_playbtn: !!playbtn,
                            has_title: !!currentsongtitle,
                            has_artist: !!currentartist,
                            url: window.location.href
                        }));
                        return;
                    }
                    
                    var title_parts = currentsongtitle.innerText.split('\n');
                    var final_title = title_parts.length > 1 ? title_parts[1] : title_parts[0];
                    
                    var artist = currentartist.innerText;
                    var playing = playbtn.classList.contains("playing");
                    
                    var currentduration = "";
                    var cur_el = document.querySelectorAll(".playbackTimeline__timePassed span")[1];
                    if (cur_el) currentduration = cur_el.innerText;
                    
                    var endduration = "";
                    var end_el = document.querySelectorAll(".playbackTimeline__duration span")[1];
                    if (end_el) endduration = end_el.innerText;
                    
                    var cover = "";
                    // Use only the bottom player badge — it always shows the current track.
                    // Other page elements (tiles, artwork blocks) can match wrong/stale elements.
                    var cover_selectors = [
                        ".playbackSoundBadge .sc-artwork span[style]",
                        ".playbackSoundBadge .image__lightOutline span[style]",
                        ".playControls__soundBadge .sc-artwork span[style]",
                        ".playControls__soundBadge .image__lightOutline span[style]"
                    ];
                    for (var si = 0; si < cover_selectors.length; si++) {
                        var cover_el = document.querySelector(cover_selectors[si]);
                        if (!cover_el) continue;
                        var cover_style = cover_el.getAttribute("style") || "";
                        var cover_matches = cover_style.match(/url\(["']?(https?:\/\/[^"')]+)["']?\)/);
                        if (cover_matches && cover_matches[1] && cover_matches[1].includes("sndcdn.com")) {
                            cover = cover_matches[1].replace(/t\d+x\d+/, "t500x500");
                            break;
                        }
                    }

                    
                    console.log("SOUNDCLOUD_RPC_UPDATE:" + JSON.stringify({
                        title: final_title,
                        artist: artist,
                        playing: playing,
                        current_duration: currentduration,
                        end_duration: endduration,
                        cover: cover
                    }));
                } catch (e) {
                    console.log("SOUNDCLOUD_RPC_ERROR:" + e.message);
                }
            }
            
            var target = document.querySelector(".playControls");
            if (!target) {
                window.soundcloud_rpc_observer_set = false;
                return;
            }
            
            // Debounce: collapse rapid DOM mutations into one update per 300ms
            var debounceTimer = null;
            var observer = new MutationObserver(function(mutations) {
                if (debounceTimer) clearTimeout(debounceTimer);
                debounceTimer = setTimeout(sendUpdate, 300);
            });
            
            observer.observe(target, {
                childList: true,
                subtree: true,
                attributes: true,
                characterData: true
            });
            
            sendUpdate();
            console.log("SOUNDCLOUD_RPC: Observer successfully started!");
        })();
        """

        # Timer to verify observer is attached (runs infrequently, every 10 seconds)
        self.timer = QTimer()
        self.timer.timeout.connect(self.poll_state)
        self.timer.start(10000)

    def create_tray(self):
        self.tray_icon = QSystemTrayIcon(self)
        icon = QIcon.fromTheme("soundcloud-desktop", QIcon.fromTheme("audio-player", QIcon.fromTheme("audio-x-generic")))
        self.tray_icon.setIcon(icon)

        # Menu
        self.tray_menu = QMenu(self)

        # Play/Pause toggle
        play_action = QAction("Play / Pause", self)
        play_action.triggered.connect(self.trigger_play_pause)
        self.tray_menu.addAction(play_action)

        # Show/Hide window
        toggle_window_action = QAction("Show / Hide Window", self)
        toggle_window_action.triggered.connect(self.toggle_window)
        self.tray_menu.addAction(toggle_window_action)

        self.tray_menu.addSeparator()

        # Quit
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(self.quit_app)
        self.tray_menu.addAction(quit_action)

        self.tray_icon.setContextMenu(self.tray_menu)
        self.tray_icon.activated.connect(self.tray_activated)
        self.tray_icon.show()

    def tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.toggle_window()

    def toggle_window(self):
        if self.isVisible():
            self.hide()
        else:
            self.show()
            self.raise_()
            self.activateWindow()

    def raise_window(self):
        self.show()
        self.raise_()
        self.activateWindow()

    def quit_app(self):
        self.really_quit = True
        self.tray_icon.hide()
        QApplication.quit()

    # MPRIS Trigger actions (interacting with DOM)
    def trigger_play_pause(self):
        self.view.page().runJavaScript('var btn = document.querySelector(".playControl"); if (btn) btn.click();')

    def trigger_next(self):
        self.view.page().runJavaScript('var btn = document.querySelector(".skipControl__next"); if (btn) btn.click();')

    def trigger_prev(self):
        self.view.page().runJavaScript('var btn = document.querySelector(".skipControl__previous"); if (btn) btn.click();')

    def trigger_play(self):
        self.view.page().runJavaScript(
            'var btn = document.querySelector(".playControl"); if (btn && !btn.classList.contains("playing")) btn.click();'
        )

    def trigger_pause(self):
        self.view.page().runJavaScript(
            'var btn = document.querySelector(".playControl"); if (btn && btn.classList.contains("playing")) btn.click();'
        )

    def connect_discord(self):
        # Close existing connection before reconnecting to avoid socket leaks
        if self.RPC is not None:
            try:
                self.RPC.close()
            except Exception:
                pass
            self.RPC = None
        try:
            self.RPC = Presence(self.client_id)
            self.RPC.connect()
            self.rpc_connected = True
            print("Discord RPC successfully connected!")
        except Exception as e:
            self.rpc_connected = False
            print(f"Waiting for Discord... ({e})")

    def inject_observer(self):
        self.view.page().runJavaScript(self.observer_js_code)

    def poll_state(self):
        if not self.rpc_connected:
            self.connect_discord()
        self.inject_observer()

    def parse_time_to_seconds(self, time_str):
        if not time_str:
            return 0
        parts = time_str.split(':')
        try:
            if len(parts) == 2:
                return int(parts[0]) * 60 + int(parts[1])
            elif len(parts) == 3:
                return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
        except ValueError:
            pass
        return 0

    def handle_js_result(self, result_str):
        if not result_str:
            return

        try:
            result = json.loads(result_str)
        except Exception as e:
            print("Error parsing JSON:", e)
            return

        if "error" in result or "debug" in result:
            self.is_playing = False
            self.playback_status = "Stopped"
            # Idle state
            if self.last_state != "idle" and self.rpc_connected and self.RPC is not None:
                try:
                    self.RPC.update(
                        activity_type=ActivityType.LISTENING,
                        details="Exploring SoundCloud",
                        state="Browsing tracks...",
                        large_image="bw-exploring-bordered-white",
                        large_text="SoundCloud Desktop",
                        small_image="bw-icon-bordered-white"
                    )
                    self.last_state = "idle"
                    self.last_track = None
                    self.last_cover = None
                    self.last_start_time = None
                except Exception as e:
                    print("Error updating RPC (idle):", e)
                    self.rpc_connected = False
            return

        title = result.get("title", "Unknown Title")
        artist = result.get("artist", "Unknown Artist")
        playing = result.get("playing", False)
        cover = result.get("cover", "")
        current_duration = result.get("current_duration", "0:00")
        end_duration = result.get("end_duration", "0:00")

        # Log only when something meaningful changes
        if title != self.last_track or cover != self.last_cover:
            print(f"[Track] {title} | Cover: {cover or '(empty)'}")
            print(f"  Selector found: {'yes' if cover else 'NO — will use default SC logo'}")

        self.is_playing = playing
        self.playback_status = "Playing" if playing else "Paused"

        current_sec = self.parse_time_to_seconds(current_duration)
        total_sec = self.parse_time_to_seconds(end_duration)
        
        now = int(time.time())
        start_time = now - current_sec
        end_time = start_time + total_sec if total_sec else None
        
        time_diff = abs(self.last_start_time - start_time) if self.last_start_time is not None else float('inf')
        
        if not self.rpc_connected or self.RPC is None:
            return

        if not playing:
            # Paused — show only status, no track info
            if self.last_state != "paused":
                try:
                    self.RPC.update(
                        activity_type=ActivityType.LISTENING,
                        details="Paused",
                        large_image="bw-exploring-bordered-white",
                        large_text="SoundCloud Desktop",
                        small_image="bw-icon-bordered-white"
                    )
                    self.last_state = "paused"
                    self.last_track = None
                    self.last_start_time = None
                except Exception as e:
                    print("Error updating RPC (paused):", e)
                    self.rpc_connected = False
        else:
            # Playing
            effective_cover = cover if cover else "bw-exploring-bordered-white"
            if self.last_state != "playing" or self.last_track != title or self.last_cover != effective_cover or time_diff > 2:
                try:
                    self.RPC.update(
                        activity_type=ActivityType.LISTENING,
                        details=title,
                        state=f"by {artist}",
                        large_image=effective_cover,
                        small_image="bw-icon-bordered-white",
                        start=start_time,
                        end=end_time
                    )
                    self.last_state = "playing"
                    self.last_track = title
                    self.last_cover = effective_cover
                    self.last_start_time = start_time
                except Exception as e:
                    print("Error updating RPC (playing):", e)
                    self.rpc_connected = False

    def closeEvent(self, event):
        # Hide instead of close if really_quit is not set
        if not self.really_quit:
            self.hide()
            event.ignore()
        else:
            if self.RPC:
                try:
                    self.RPC.close()
                except Exception:
                    pass
            event.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    client = SoundCloudClient()
    client.show()
    sys.exit(app.exec())
