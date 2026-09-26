#!/usr/bin/env python3
"""Standalone preview of the idle-screen themes: python3 qml/preview.py [--shots DIR]."""
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

here = Path(__file__).resolve().parent
shots = sys.argv[sys.argv.index("--shots") + 1] if "--shots" in sys.argv else ""

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
engine.setInitialProperties({"shotsDir": shots})
engine.load(QUrl.fromLocalFile(str(here / "Preview.qml")))
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
