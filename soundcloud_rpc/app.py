import sys
import os
import json
import time
import asyncio
import threading
import hashlib
from collections import deque
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from PySide6.QtCore import Qt, QUrl, QTimer, Slot, Property, ClassInfo, QMetaType, QEvent, QSettings
from PySide6.QtWidgets import QApplication, QMainWindow, QVBoxLayout, QWidget, QSystemTrayIcon, QMenu, QStackedWidget
from PySide6.QtGui import QIcon, QAction, QActionGroup, QDesktopServices, QShortcut, QKeySequence, QGuiApplication
from PySide6.QtQuickWidgets import QQuickWidget
from PySide6.QtWebEngineCore import QWebEngineProfile, QWebEnginePage, QWebEngineUrlRequestInterceptor, QWebEngineScript
from PySide6.QtWebEngineWidgets import QWebEngineView
from PySide6.QtDBus import QDBusAbstractAdaptor, QDBusArgument, QDBusConnection, QDBusMessage, QDBusObjectPath
from pypresence import Presence, ActivityType
try:
    from pypresence.exceptions import DiscordError
except ImportError:  # pragma: no cover
    class DiscordError(Exception):
        pass


PACKAGE_DIR = Path(__file__).resolve().parent
QML_DIR = PACKAGE_DIR / "qml"
ICON_PATH = PACKAGE_DIR / "soundcloud.png"

IDLE_TIMEOUT_MS = 30_000  # no input for this long while playing -> show the idle screen
IDLE_RETRY_MS = 5_000  # re-check interval when the timeout elapsed but the idle screen is not allowed yet
IDLE_CYCLE_MS = 90_000  # theme rotation period when "Cycle Themes" is on
IDLE_ENTER_GRACE_S = 0.6  # ignore input right after entering idle (layout changes emit synthetic mouse moves)
IDLE_MOVE_THRESHOLD = 4  # px the pointer must travel to count as activity
DEFAULT_IDLE_THEME = "GlassCard"
IDLE_THEMES = [
    ("GlassCard", "Glass Card"),
    ("BlurCover", "Blur Cover"),
    ("Aurora", "Aurora"),
    ("Vinyl", "Vinyl"),
    ("Cassette", "Cassette"),
    ("Particles", "Particles"),
    ("Equalizer", "Equalizer"),
    ("Polaroid", "Polaroid"),
    ("MinimalClock", "Minimal Clock"),
    ("Typography", "Typography"),
    ("Neon", "Neon"),
    ("AlbumWall", "Album Wall"),
    ("Orbit", "Orbit"),
    ("Starfield", "Starfield"),
]
IDLE_ACTIVITY_EVENTS = {
    QEvent.Type.MouseButtonPress,
    QEvent.Type.MouseButtonDblClick,
    QEvent.Type.Wheel,
    QEvent.Type.KeyPress,
    QEvent.Type.TouchBegin,
}


def clean_rpc_text(text, fallback=""):
    """Discord rejects details/state shorter than 2 or longer than 128 bytes; a rejected payload used to look like a dropped connection."""
    text = (text or fallback).strip()
    text = text.encode("utf-8")[:128].decode("utf-8", "ignore").strip()
    if len(text) < 2:
        text = text.ljust(2, "\u2800")
    return text


class DiscordRpcWorker(threading.Thread):
    """Owns the Discord IPC connection on its own thread so blocking pipe I/O never freezes the GUI.

    The GUI only publishes the *desired* activity via set_activity(); the worker always converges to the
    latest one (rate limited), reconnects with backoff, and re-sends after a reconnect. Because the desired
    state is retained, an update throttled by the rate limit is delayed instead of lost.
    """

    # Discord accepts about 5 activity updates per 20s, so allow short bursts instead of a fixed gap
    # between updates; a fixed gap made every transient state during a track skip cost seconds.
    RATE_LIMIT_COUNT = 4
    RATE_LIMIT_WINDOW = 20.0
    # Wait briefly after the last real change so transient UI states (new title, old cover, stale
    # time) collapse into the final one instead of being sent one by one.
    SETTLE_DELAY = 0.25
    RECONNECT_INTERVAL = 5.0

    def __init__(self, client_id):
        super().__init__(daemon=True, name="discord-rpc")
        self.client_id = client_id
        self._lock = threading.Lock()
        self._wake = threading.Event()
        self._stopping = False
        self._desired = None
        self._dirty = False
        self._changed_at = 0.0

    def set_activity(self, activity):
        with self._lock:
            # Only a real change restarts the settle timer, so the 1s heartbeat can't starve sending
            if not self._same(activity, self._desired):
                self._changed_at = time.monotonic()
            self._desired = activity
            self._dirty = True
        self._wake.set()

    def stop(self):
        self._stopping = True
        self._wake.set()

    @staticmethod
    def _same(a, b):
        if a is None or b is None:
            return a is b
        keys = ("details", "state", "large_image", "small_image", "large_text", "buttons")
        if any(a.get(k) != b.get(k) for k in keys):
            return False
        # Playing activities carry timestamps: only resend when the start moved (seek) or the end changed
        if (a.get("start") is None) != (b.get("start") is None):
            return False
        if a.get("start") is not None and abs(a["start"] - b["start"]) > 5:
            return False
        if (a.get("end") is None) != (b.get("end") is None):
            return False
        if a.get("end") is not None and abs(a["end"] - b["end"]) > 5:
            return False
        return True

    def _ipc_pipes(self):
        xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        for sub in ("app/com.discordapp.Discord", "app/dev.vencord.Vesktop", "snap.discord"):
            for i in range(10):
                pipe = Path(xdg_runtime) / sub / f"discord-ipc-{i}"
                if pipe.exists():
                    yield pipe

    def _connect(self, loop):
        try:
            rpc = Presence(self.client_id, loop=loop)
            rpc.connect()
            print("Discord RPC successfully connected!")
            return rpc
        except Exception as e:
            err = e
        for pipe in self._ipc_pipes():
            try:
                rpc = Presence(self.client_id, pipe=str(pipe), loop=loop)
                rpc.connect()
                print(f"Discord RPC connected via custom pipe {pipe}!")
                return rpc
            except Exception:
                pass
        print(f"Waiting for Discord... ({err})")
        return None

    @staticmethod
    def _close(rpc):
        try:
            rpc.close()
        except Exception:
            pass

    def run(self):
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        rpc = None
        last_sent = None
        sent_times = deque()
        next_connect = 0.0
        try:
            while not self._stopping:
                self._wake.clear()
                now = time.monotonic()

                if rpc is None:
                    if now >= next_connect:
                        rpc = self._connect(loop)
                        last_sent = None
                        if rpc is None:
                            next_connect = time.monotonic() + self.RECONNECT_INTERVAL
                    self._wake.wait(1.0 if rpc is None else 0)
                    continue

                with self._lock:
                    dirty, desired, changed_at = self._dirty, self._desired, self._changed_at

                timeout = None
                if dirty and self._same(desired, last_sent):
                    with self._lock:
                        if self._desired is desired:
                            self._dirty = False
                elif dirty:
                    while sent_times and now - sent_times[0] >= self.RATE_LIMIT_WINDOW:
                        sent_times.popleft()
                    delay = changed_at + self.SETTLE_DELAY - now
                    if len(sent_times) >= self.RATE_LIMIT_COUNT:
                        delay = max(delay, sent_times[0] + self.RATE_LIMIT_WINDOW - now)
                    if delay > 0:
                        timeout = delay
                    else:
                        try:
                            if desired is None:
                                rpc.clear()
                            else:
                                rpc.update(**desired)
                            last_sent = desired
                            sent_times.append(time.monotonic())
                            with self._lock:
                                if self._desired is desired:
                                    self._dirty = False
                        except DiscordError as e:
                            # Discord rejected this payload; the connection is fine, so don't reconnect or retry it
                            print("Discord rejected activity:", e)
                            sent_times.append(time.monotonic())
                            with self._lock:
                                if self._desired is desired:
                                    self._dirty = False
                        except Exception as e:
                            print("Discord RPC connection lost:", e)
                            self._close(rpc)
                            rpc = None
                            next_connect = time.monotonic() + self.RECONNECT_INTERVAL
                            continue
                self._wake.wait(timeout)
        finally:
            if rpc is not None:
                self._close(rpc)
            loop.close()

MPRIS_PATH = "/org/mpris/MediaPlayer2"
MPRIS_NO_TRACK = "/org/mpris/MediaPlayer2/TrackList/NoTrack"

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
        <property name="DesktopEntry" type="s" access="read"/>
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
    DesktopEntry = Property(str, fget=lambda self: "soundcloud-rpc")
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
        <method name="Stop"/>
        <property name="PlaybackStatus" type="s" access="read"/>
        <property name="Metadata" type="a{sv}" access="read"/>
        <property name="Position" type="x" access="read"/>
        <property name="Rate" type="d" access="read"/>
        <property name="MinimumRate" type="d" access="read"/>
        <property name="MaximumRate" type="d" access="read"/>
        <property name="Volume" type="d" access="read"/>
        <property name="CanSeek" type="b" access="read"/>
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

    @Slot()
    def Stop(self):
        self.parent().trigger_pause()

    PlaybackStatus = Property(str, fget=lambda self: self.parent().playback_status)
    Metadata = Property("QVariantMap", fget=lambda self: self.parent().mpris_metadata)
    Position = Property("qlonglong", fget=lambda self: self.parent().mpris_position_us())
    Rate = Property(float, fget=lambda self: 1.0)
    MinimumRate = Property(float, fget=lambda self: 1.0)
    MaximumRate = Property(float, fget=lambda self: 1.0)
    Volume = Property(float, fget=lambda self: 1.0)
    CanSeek = Property(bool, fget=lambda self: False)
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
        elif message == "SOUNDCLOUD_RPC_ACTIVITY":
            self.parent().note_activity()
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
        self.mpris_metadata = {"mpris:trackid": QDBusObjectPath(MPRIS_NO_TRACK)}
        self.mpris_position = (0, time.monotonic())  # (seconds at receipt, monotonic receipt time)

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

        # Report user input inside the page (throttled) so the idle screen knows when the user is active.
        # Qt-level input events over QtWebEngine are not observable from Python without an application-wide
        # event filter, which crashes PySide on non-wrapped QObjects.
        activity_script = QWebEngineScript()
        activity_script.setName("activity")
        activity_script.setSourceCode("""
            (function() {
                var last = 0;
                function ping() {
                    var now = Date.now();
                    if (now - last < 1000) return;
                    last = now;
                    console.log("SOUNDCLOUD_RPC_ACTIVITY");
                }
                ["mousemove", "mousedown", "wheel", "keydown", "touchstart"].forEach(function(name) {
                    window.addEventListener(name, ping, {capture: true, passive: true});
                });
            })();
        """)
        activity_script.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentReady)
        activity_script.setWorldId(QWebEngineScript.ScriptWorldId.ApplicationWorld)
        activity_script.setRunsOnSubFrames(False)
        self.profile.scripts().insert(activity_script)

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

        # Idle screen (QML) lives on the second stack page above the site; the site keeps running underneath
        self.idle_view = QQuickWidget()
        self.idle_view.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView)
        self.idle_view.setMouseTracking(True)
        self.idle_view.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.idle_view.setSource(QUrl.fromLocalFile(str(QML_DIR / "IdleScreen.qml")))
        self.idle_root = self.idle_view.rootObject()
        if self.idle_root is None:
            print("Idle screen disabled, QML failed to load:", [e.toString() for e in self.idle_view.errors()])

        self.stack = QStackedWidget()
        self.stack.addWidget(self.view)
        self.stack.addWidget(self.idle_view)

        # Layout
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.stack)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        self.init_idle_screen()

        # Discord RPC (runs on its own thread)
        self.client_id = "1289606421368799345"  # SoundCloud assets
        self.idle_count = 0
        self.last_logged_track = None
        self.rpc = DiscordRpcWorker(self.client_id)
        self.rpc.start()

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
                    final_title = final_title ? final_title.trim() : "";
                    
                    var artist = currentartist.innerText ? currentartist.innerText.trim() : "";
                    var playing = playbtn.classList.contains("playing");

                    var link_el = currentsongtitle.href ? currentsongtitle : document.querySelector(".playbackSoundBadge__titleLink");
                    var track_url = link_el && link_el.href ? link_el.href.split("?")[0] : "";
                    
                    var currentduration = "";
                    var cur_el = document.querySelectorAll(".playbackTimeline__timePassed span")[1];
                    if (cur_el) currentduration = cur_el.innerText;
                    
                    var endduration = "";
                    var end_el = document.querySelectorAll(".playbackTimeline__duration span")[1];
                    if (end_el) endduration = end_el.innerText;
                    
                    var cover = "";
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
                    if (!cover) {
                        var img_el = document.querySelector(".playbackSoundBadge img, .playControls__soundBadge img");
                        if (img_el && img_el.src && img_el.src.includes("sndcdn.com")) {
                            cover = img_el.src.replace(/t\d+x\d+/, "t500x500");
                        }
                    }

                    console.log("SOUNDCLOUD_RPC_UPDATE:" + JSON.stringify({
                        title: final_title,
                        artist: artist,
                        playing: playing,
                        current_duration: currentduration,
                        end_duration: endduration,
                        cover: cover,
                        url: track_url
                    }));
                } catch (e) {
                    console.log("SOUNDCLOUD_RPC_ERROR:" + e.message);
                }
            }
            
            var target = document.querySelector(".playControls");
            if (!target) {
                // Player bar not on the page: report it so Python can fall back to the idle status
                window.soundcloud_rpc_observer_set = false;
                sendUpdate();
                return;
            }

            // Re-initialisation must not stack observers
            if (window.soundcloud_rpc_observer) window.soundcloud_rpc_observer.disconnect();
            
            // Debounce: collapse rapid DOM mutations into one update per 100ms
            var debounceTimer = null;
            var observer = new MutationObserver(function(mutations) {
                if (debounceTimer) clearTimeout(debounceTimer);
                debounceTimer = setTimeout(sendUpdate, 100);
            });
            window.soundcloud_rpc_observer = observer;

            // Heartbeat: state changes must never depend on a mutation being observed
            if (window.soundcloud_rpc_heartbeat) clearInterval(window.soundcloud_rpc_heartbeat);
            window.soundcloud_rpc_heartbeat = setInterval(sendUpdate, 1000);
            
            observer.observe(target, {
                childList: true,
                subtree: true,
                attributes: true,
                characterData: true
            });
            
            // Handle SPA Navigation seamlessly
            if (!window.soundcloud_rpc_history_patched) {
                window.soundcloud_rpc_history_patched = true;
                var _pushState = history.pushState.bind(history);
                var _replaceState = history.replaceState.bind(history);
                function onNavigate() {
                    console.log("SOUNDCLOUD_RPC: SPA navigation detected, re-initializing...");
                    window.soundcloud_rpc_observer_set = false;
                    setTimeout(function() { if (typeof sendUpdate === 'function') sendUpdate(); }, 500);
                    setTimeout(function() { if (typeof sendUpdate === 'function') sendUpdate(); }, 1500);
                }
                history.pushState = function() { _pushState.apply(history, arguments); onNavigate(); };
                history.replaceState = function() { _replaceState.apply(history, arguments); onNavigate(); };
            }
            
            sendUpdate();
            console.log("SOUNDCLOUD_RPC: Observer successfully started!");
        })();
        """

        # Fast polling timer (runs every 3 seconds to check connection and observer status)
        self.timer = QTimer()
        self.timer.timeout.connect(self.poll_state)
        self.timer.start(3000)

        # Setup Ctrl+F shortcut to focus search bar
        self.search_shortcut = QShortcut(QKeySequence("Ctrl+F"), self)
        self.search_shortcut.activated.connect(self.focus_search_bar)

    def focus_search_bar(self):
        js_focus_search = """
        (function() {
            var searchInput = document.querySelector('.headerSearch__input') || 
                              document.querySelector('input[type="search"]') || 
                              document.querySelector('.header__search input');
            if (searchInput) {
                searchInput.focus();
                searchInput.select();
            }
        })();
        """
        self.view.page().runJavaScript(js_focus_search)

    def copy_track_link(self):
        js_get_link = """
        (function() {
            var el = document.querySelector(".playbackSoundBadge__title");
            if (el && el.href) {
                return el.href;
            }
            return window.location.href;
        })();
        """
        def on_link_retrieved(url):
            if url:
                QGuiApplication.clipboard().setText(url)
                print(f"[Clipboard] Copied track link: {url}")
                if self.tray_icon:
                    self.tray_icon.showMessage(
                        "SoundCloud Desktop",
                        f"Link copied to clipboard: {url}",
                        QSystemTrayIcon.MessageIcon.Information,
                        2000
                    )

        self.view.page().runJavaScript(js_get_link, 0, on_link_retrieved)

    def create_tray(self):
        self.tray_icon = QSystemTrayIcon(self)
        icon = QIcon.fromTheme("soundcloud-rpc", QIcon(str(ICON_PATH)))
        if icon.isNull():
            icon = QIcon.fromTheme("audio-player", QIcon.fromTheme("audio-x-generic"))
        self.tray_icon.setIcon(icon)

        # Menu
        self.tray_menu = QMenu(self)

        # Play/Pause toggle
        play_action = QAction("Play / Pause", self)
        play_action.triggered.connect(self.trigger_play_pause)
        self.tray_menu.addAction(play_action)

        # Copy Track Link
        copy_link_action = QAction("Copy Track Link", self)
        copy_link_action.triggered.connect(self.copy_track_link)
        self.tray_menu.addAction(copy_link_action)

        # Show/Hide window
        toggle_window_action = QAction("Show / Hide Window", self)
        toggle_window_action.triggered.connect(self.toggle_window)
        self.tray_menu.addAction(toggle_window_action)

        self.tray_menu.addSeparator()
        self.create_idle_menu(self.tray_menu)
        self.tray_menu.addSeparator()

        # Quit
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(self.quit_app)
        self.tray_menu.addAction(quit_action)

        self.tray_icon.setContextMenu(self.tray_menu)
        self.tray_icon.activated.connect(self.tray_activated)
        self.tray_icon.show()

    # Idle screen
    def init_idle_screen(self):
        settings = QSettings()
        self.idle_enabled = settings.value("idle/enabled", True, type=bool)
        self.idle_cycle = settings.value("idle/cycle", False, type=bool)
        theme = settings.value("idle/theme", DEFAULT_IDLE_THEME, type=str)
        self.idle_theme = theme if theme in dict(IDLE_THEMES) else DEFAULT_IDLE_THEME
        self.idle_active = False
        self.idle_forced = False
        self.idle_entered_at = 0.0
        self.idle_last_pos = None
        self.idle_state = {"title": "", "artist": "", "cover": "", "position": 0, "duration": 1, "playing": False}

        self.idle_timer = QTimer(self)
        self.idle_timer.setSingleShot(True)
        self.idle_timer.timeout.connect(self.on_idle_timeout)
        self.idle_cycle_timer = QTimer(self)
        self.idle_cycle_timer.setInterval(IDLE_CYCLE_MS)
        self.idle_cycle_timer.timeout.connect(self.next_idle_theme)

        if self.idle_root is not None:
            self.idle_root.setProperty("theme", self.idle_theme)
            self.idle_view.installEventFilter(self)  # input over the idle page; the site reports its own input via JS
            self.restart_idle_timer()

    def create_idle_menu(self, menu):
        idle_menu = menu.addMenu("Idle Screen")

        self.idle_enabled_action = QAction("Enabled", self, checkable=True, checked=self.idle_enabled)
        self.idle_enabled_action.toggled.connect(self.set_idle_enabled)
        idle_menu.addAction(self.idle_enabled_action)

        self.idle_cycle_action = QAction("Cycle Themes", self, checkable=True, checked=self.idle_cycle)
        self.idle_cycle_action.toggled.connect(self.set_idle_cycle)
        idle_menu.addAction(self.idle_cycle_action)

        show_now = QAction("Show Now", self)
        show_now.triggered.connect(lambda: self.enter_idle(force=True))
        idle_menu.addAction(show_now)
        idle_menu.addSeparator()

        self.idle_theme_group = QActionGroup(self)
        self.idle_theme_actions = {}
        for key, label in IDLE_THEMES:
            action = QAction(label, self, checkable=True, checked=(key == self.idle_theme))
            action.triggered.connect(lambda _checked=False, k=key: self.set_idle_theme(k))
            self.idle_theme_group.addAction(action)
            idle_menu.addAction(action)
            self.idle_theme_actions[key] = action

        if self.idle_root is None:
            idle_menu.setEnabled(False)

    def set_idle_enabled(self, enabled):
        self.idle_enabled = enabled
        QSettings().setValue("idle/enabled", enabled)
        if enabled:
            self.restart_idle_timer()
        else:
            self.idle_timer.stop()
            self.exit_idle()

    def set_idle_cycle(self, enabled):
        self.idle_cycle = enabled
        QSettings().setValue("idle/cycle", enabled)
        if self.idle_active and enabled:
            self.idle_cycle_timer.start()
        else:
            self.idle_cycle_timer.stop()

    def set_idle_theme(self, key):
        self.idle_theme = key
        QSettings().setValue("idle/theme", key)
        self.idle_root.setProperty("theme", key)
        self.idle_theme_actions[key].setChecked(True)

    def next_idle_theme(self):
        keys = [k for k, _ in IDLE_THEMES]
        self.set_idle_theme(keys[(keys.index(self.idle_theme) + 1) % len(keys)])

    def restart_idle_timer(self):
        if self.idle_enabled:
            self.idle_timer.start(IDLE_TIMEOUT_MS)

    def on_idle_timeout(self):
        if not self.enter_idle():
            self.idle_timer.start(IDLE_RETRY_MS)

    def enter_idle(self, force=False):
        """Show the idle screen; returns False when it isn't allowed right now."""
        if self.idle_root is None or self.idle_active:
            return self.idle_active
        if not force and (not self.idle_enabled or self.playback_status != "Playing"):
            return False
        if not self.isVisible() or self.isMinimized():
            return False
        self.idle_active = True
        self.idle_forced = force
        self.idle_entered_at = time.monotonic()
        self.idle_last_pos = None
        self.push_idle_state()
        self.stack.setCurrentWidget(self.idle_view)
        self.idle_view.setFocus()
        self.idle_root.setProperty("active", True)
        if self.idle_cycle:
            self.idle_cycle_timer.start()
        return True

    def exit_idle(self):
        if self.idle_active:
            self.idle_active = False
            self.idle_forced = False
            self.idle_cycle_timer.stop()
            self.idle_root.setProperty("active", False)
            self.stack.setCurrentWidget(self.view)
            self.view.setFocus()
        self.restart_idle_timer()

    def push_idle_state(self):
        if self.idle_root is not None and self.idle_active:
            for key, value in self.idle_state.items():
                self.idle_root.setProperty(key, value)

    def eventFilter(self, obj, event):
        etype = event.type()
        if etype == QEvent.Type.MouseMove:
            pos = event.globalPosition().toPoint()
            last, self.idle_last_pos = self.idle_last_pos, pos
            if last is not None and (pos - last).manhattanLength() >= IDLE_MOVE_THRESHOLD:
                self.note_activity()
        elif etype in IDLE_ACTIVITY_EVENTS:
            self.note_activity()
        return False

    def note_activity(self):
        if self.idle_active:
            if time.monotonic() - self.idle_entered_at < IDLE_ENTER_GRACE_S:
                return
            self.exit_idle()
        else:
            self.restart_idle_timer()

    def hideEvent(self, event):
        self.exit_idle()
        super().hideEvent(event)

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
    def mpris_position_us(self):
        seconds, received = self.mpris_position
        if self.playback_status == "Playing":
            seconds += time.monotonic() - received
        return int(seconds * 1_000_000)

    def update_mpris(self, status, metadata, position_sec=0):
        """Store the new player state and emit PropertiesChanged; status bars only refresh on that signal."""
        self.mpris_position = (position_sec, time.monotonic())
        changed = {}
        if status != self.playback_status:
            self.playback_status = status
            changed["PlaybackStatus"] = status
            if status != "Playing" and self.idle_active and not self.idle_forced:
                self.exit_idle()
        if metadata != self.mpris_metadata:
            self.mpris_metadata = metadata
            changed["Metadata"] = metadata
        if changed:
            # The invalidated-properties argument must be `as`; a plain empty Python list is sent as `av`,
            # which strict clients such as playerctl reject with a signature mismatch.
            invalidated = QDBusArgument()
            invalidated.beginArray(QMetaType(QMetaType.Type.QString.value))
            invalidated.endArray()
            msg = QDBusMessage.createSignal(MPRIS_PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged")
            msg.setArguments(["org.mpris.MediaPlayer2.Player", changed, invalidated])
            QDBusConnection.sessionBus().send(msg)

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

    def inject_observer(self):
        self.view.page().runJavaScript(self.observer_js_code)

    def poll_state(self):
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

    IDLE_ACTIVITY = {
        "activity_type": ActivityType.LISTENING,
        "details": "Exploring SoundCloud",
        "state": "Browsing tracks...",
        "large_image": "bw-exploring-bordered-white",
        "large_text": "SoundCloud Desktop",
        "small_image": "bw-icon-bordered-white",
    }

    PAUSED_ACTIVITY = {
        "activity_type": ActivityType.LISTENING,
        "details": "Paused",
        "large_image": "bw-exploring-bordered-white",
        "large_text": "SoundCloud Desktop",
        "small_image": "bw-icon-bordered-white",
    }

    def handle_js_result(self, result_str):
        if not result_str:
            return

        try:
            result = json.loads(result_str)
        except Exception as e:
            print("Error parsing JSON:", e)
            return

        if "error" in result or "debug" in result:
            self.idle_count += 1
            # Require 3 consecutive debug results before switching to idle
            # to avoid transient UI flickers during SPA navigation / track changes
            if self.idle_count >= 3:
                self.is_playing = False
                self.update_mpris("Stopped", {"mpris:trackid": QDBusObjectPath(MPRIS_NO_TRACK)})
                self.last_logged_track = None
                self.rpc.set_activity(self.IDLE_ACTIVITY)
            return

        self.idle_count = 0

        title = result.get("title") or "Unknown Title"
        artist = result.get("artist") or "Unknown Artist"
        playing = result.get("playing", False)
        cover = result.get("cover", "")

        if (title, cover) != self.last_logged_track:
            self.last_logged_track = (title, cover)
            print(f"[Track] {title} | Cover: {cover or '(empty)'}")

        current_sec = self.parse_time_to_seconds(result.get("current_duration"))
        total_sec = self.parse_time_to_seconds(result.get("end_duration"))
        track_url = result.get("url") or ""

        self.is_playing = playing
        track_id = hashlib.md5((track_url or f"{artist}-{title}").encode()).hexdigest()
        metadata = {
            "mpris:trackid": QDBusObjectPath(f"/org/soundcloud_rpc/track/{track_id}"),
            "xesam:title": title,
            "xesam:artist": [artist],
        }
        if total_sec:
            metadata["mpris:length"] = total_sec * 1_000_000
        if cover:
            metadata["mpris:artUrl"] = cover
        if track_url:
            metadata["xesam:url"] = track_url
        self.update_mpris("Playing" if playing else "Paused", metadata, current_sec)
        self.idle_state = {
            "title": title,
            "artist": artist,
            "cover": cover,
            "position": current_sec,
            "duration": total_sec or 1,
            "playing": playing,
        }
        self.push_idle_state()

        if not playing:
            self.rpc.set_activity(self.PAUSED_ACTIVITY)
            return

        start_time = int(time.time()) - current_sec

        activity = {
            "activity_type": ActivityType.LISTENING,
            "details": clean_rpc_text(title),
            "state": clean_rpc_text(f"by {artist}"),
            "large_image": cover or "bw-exploring-bordered-white",
            "small_image": "bw-icon-bordered-white",
            "start": start_time,
            "end": start_time + total_sec if total_sec else None,
        }

        # Spotify-style "Listen" button; Discord requires an http(s) URL of at most 512 chars
        if track_url.startswith("https://") and len(track_url) <= 512:
            activity["buttons"] = [{"label": "Listen on SoundCloud", "url": track_url}]

        self.rpc.set_activity(activity)

    def closeEvent(self, event):
        # Hide instead of close if really_quit is not set
        if not self.really_quit:
            self.hide()
            event.ignore()
        else:
            self.rpc.stop()
            self.rpc.join(timeout=2)
            event.accept()


def main():
    import argparse

    parser = argparse.ArgumentParser(description="SoundCloud Desktop Player with Discord RPC & MPRIS")
    parser.add_argument("--minimized", "--tray", "-m", "-t", action="store_true", help="Start application minimized to system tray")
    args = parser.parse_args()

    app = QApplication(sys.argv)
    app.setApplicationName("soundcloud-rpc")
    app.setApplicationDisplayName("SoundCloud Desktop")
    app.setOrganizationName("SoundCloud")
    app.setDesktopFileName("soundcloud-rpc")

    # Set application icon
    if ICON_PATH.exists():
        app.setWindowIcon(QIcon(str(ICON_PATH)))

    client = SoundCloudClient()

    if not args.minimized:
        client.show()
    else:
        print("Starting SoundCloud Desktop minimized to system tray...")

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
