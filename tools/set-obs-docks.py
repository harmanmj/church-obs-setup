#!/usr/bin/env python3
"""Install the OBS window layout in obs-configuration/obs-layout.ini, and open OBS in studio mode.

Usage: set-obs-docks.py OBS_CONFIG_DIR   (e.g. ~/.var/app/com.obsproject.Studio/config/obs-studio)
The layout (window, docks with PTZ Controls in place, side docks, vertical mixer, multiview) goes in once per
version of obs-layout.ini: user.ini remembers which one it got (ChurchLayout), so changes made in OBS survive
a re-run until the repo's layout changes. Also turns off OBS's popup about closing a dock. Close OBS first: it
writes its own layout when it exits. The Windows twin is set-obs-docks.ps1.
"""
import configparser
import hashlib
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


layout = dict(load(LAYOUT)["BasicWindow"])
# Which layout this is: the same in set-obs-docks.ps1 (key=value lines in file order, each ending in \n).
version = hashlib.sha256("".join(f"{k}={v}\n" for k, v in layout.items()).encode()).hexdigest()[:12]

ini = pathlib.Path(sys.argv[1]) / "user.ini"
user = load(ini)
# Skip OBS's "You just closed a dockable window" popup.
section(user, "General")["WarnedAboutClosingDocks"] = "true"
window = section(user, "BasicWindow")
# Open OBS in studio mode. OBS saves this on exit, so it is only the starting state.
window["PreviewProgramMode"] = "true"
if window.get("ChurchLayout") == version:
    print("The OBS layout is already this version; leaving it alone (studio mode on).")
else:
    window.update(layout)
    window["ChurchLayout"] = version
    print(f"OBS layout (PTZ Controls docked, studio mode on) installed in {ini}")
save(user, ini)
