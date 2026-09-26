#!/usr/bin/env python3
"""Standalone preview of the idle-screen themes: preview.py [--shots DIR] [--cover FILE] [--size WxH] [--fixed] [--only Theme,Theme]."""
import sys
from pathlib import Path

from PySide6.QtCore import QSize, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

here = Path(__file__).resolve().parent


def opt(name, default=""):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


shots = opt("--shots")
cover = opt("--cover")
only = opt("--only")
fixed = "--fixed" in sys.argv
width, height = (int(v) for v in opt("--size", "1431x500").split("x"))

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
props = {"shotsDir": shots, "width": width, "height": height, "themeFilter": only}
if cover:
    props["coverUrl"] = QUrl.fromLocalFile(cover)
engine.setInitialProperties(props)
engine.load(QUrl.fromLocalFile(str(here / "Preview.qml")))
if not engine.rootObjects():
    sys.exit(1)
if fixed:  # a fixed-size window is floated by tiling compositors, so it renders at exactly this size
    win = engine.rootObjects()[0]
    win.setMinimumSize(QSize(width, height))
    win.setMaximumSize(QSize(width, height))
sys.exit(app.exec())
