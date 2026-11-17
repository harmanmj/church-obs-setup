#!/usr/bin/env python3
"""Install the OBS window layout in obs-configuration/obs-layout.ini, and open OBS in studio mode.

Usage: set-obs-docks.py OBS_CONFIG_DIR [--keep-studio-mode-off]
       (e.g. ~/.var/app/com.obsproject.Studio/config/obs-studio)
Every run puts the layout back (window, docks with PTZ Controls in place, side docks, vertical mixer), so a dock
closed or moved by accident is fixed by the next setup or update. It turns studio mode on; with
--keep-studio-mode-off (the update scripts use it), studio mode that was turned off is left off. Also turns off
OBS's popup about closing a dock. Close OBS first: it writes its own layout when it exits. The Windows twin is
set-obs-docks.ps1.
"""
import configparser
import pathlib
import sys

LAYOUT = pathlib.Path(__file__).resolve().parent.parent / "obs-configuration" / "obs-layout.ini"


def load(path):
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str  # OBS keys are case-sensitive
    if path.exists():
        cp.read(path, encoding="utf-8-sig")
    return cp


def save(cp, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        cp.write(f, space_around_delimiters=False)


def section(cp, name):
    if not cp.has_section(name):
        cp.add_section(name)
    return cp[name]


keep_off = False
for arg in sys.argv[2:]:
    if arg == "--keep-studio-mode-off":
        keep_off = True
    else:
        sys.exit(f"Unknown option: {arg}")

ini = pathlib.Path(sys.argv[1]) / "user.ini"
user = load(ini)
# Skip OBS's "You just closed a dockable window" popup.
section(user, "General")["WarnedAboutClosingDocks"] = "true"
window = section(user, "BasicWindow")
window.update(load(LAYOUT)["BasicWindow"])
window.pop("ChurchLayout", None)  # left by an older version of this script, which installed each layout only once
# Studio mode on (OBS saves the mode on exit, so this is only the starting state), unless the update asks to
# leave it off on a computer where it was turned off.
studio = "off" if keep_off and window.get("PreviewProgramMode", "").lower() == "false" else "on"
window["PreviewProgramMode"] = "true" if studio == "on" else "false"
save(user, ini)
print(f"OBS layout (PTZ Controls docked) installed in {ini}; studio mode {studio}")
