from pathlib import Path

import PyInstaller.__main__


def install():
    """Make package."""

    HERE = Path(__file__).parent.absolute()
    path_to_main = str(HERE / "main.py")
    PyInstaller.__main__.run([path_to_main, "--onefile", "--console"])
