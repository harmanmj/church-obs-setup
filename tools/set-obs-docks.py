#!/usr/bin/env python3
"""Install the OBS window layout in configs/obs-layout.ini, which has the PTZ Controls dock in place.

Usage: set-obs-docks.py OBS_CONFIG_DIR   (e.g. ~/.var/app/com.obsproject.Studio/config/obs-studio)
Keeps the layout already there if PTZ Controls is docked in it, so changes made in OBS survive a re-run.
Also turns off OBS's popup about closing a dock.
"""
import base64
import configparser
import pathlib
import sys

LAYOUT = pathlib.Path(__file__).resolve().parent.parent / "configs" / "obs-layout.ini"
PTZ_DOCK = "ptz-dock".encode("utf-16-be")  # names in Qt's saved window state are UTF-16
DOCKED = 1  # the flags byte after the name: 1 visible, 2 floating


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


def ptz_docked(dock_state):
    state = base64.b64decode(dock_state)
    i = state.find(PTZ_DOCK)
    return i >= 0 and state[i + len(PTZ_DOCK)] == DOCKED


ini = pathlib.Path(sys.argv[1]) / "user.ini"
user = load(ini)
# Skip OBS's "You just closed a dockable window" popup.
if not user.has_section("General"):
    user.add_section("General")
user["General"]["WarnedAboutClosingDocks"] = "true"
if ptz_docked(user.get("BasicWindow", "DockState", fallback="")):
    save(user, ini)
    print("PTZ Controls is already docked; leaving the OBS layout alone.")
    sys.exit()

if not user.has_section("BasicWindow"):
    user.add_section("BasicWindow")
user["BasicWindow"].update(load(LAYOUT)["BasicWindow"])
save(user, ini)
print(f"OBS layout with PTZ Controls docked installed in {ini}")
