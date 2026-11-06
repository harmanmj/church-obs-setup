#!/usr/bin/env python3
"""Point OBS's audio monitoring device at the virtual "OBS Monitoring (not for Zoom)" sink (see audio/obs-to-zoom.conf),
set its video to 1920x1080 at 30 fps with recording the same as the stream, open OBS in studio mode, and skip its
Auto-Configuration Wizard.

Usage: set-obs-monitor.py OBS_CONFIG_DIR  (e.g. ~/.var/app/com.obsproject.Studio/config/obs-studio)
Sets these in every existing profile; if OBS has never been run, creates a "Church" profile with them.
OBS saves studio mode on exit, so it is only the starting state.
"""
import configparser
import pathlib
import sys

DEVICE_ID = "obs_zoom"
DEVICE_NAME = "OBS Monitoring (not for Zoom)"
# The scene collections are laid out for a 1920x1080 canvas.
VIDEO = {"BaseCX": "1920", "BaseCY": "1080", "OutputCX": "1920", "OutputCY": "1080", "FPSType": "0", "FPSCommon": "30"}


def load(path):
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str  # OBS keys are case-sensitive
    if path.exists():
        cp.read(path, encoding="utf-8-sig")
    return cp


def save(cp, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        cp.write(f, space_around_delimiters=False)


root = pathlib.Path(sys.argv[1])
user = load(root / "user.ini")
if not user.has_section("BasicWindow"):
    user.add_section("BasicWindow")
user["BasicWindow"]["PreviewProgramMode"] = "true"
# With the video set, skip OBS's Auto-Configuration Wizard on first start.
if not user.has_section("General"):
    user.add_section("General")
user["General"]["FirstRun"] = "true"
profiles = sorted(p for p in (root / "basic" / "profiles").glob("*") if p.is_dir())
if not profiles:
    profiles = [root / "basic" / "profiles" / "Church"]
    if not user.has_section("Basic"):
        user.add_section("Basic")
    user["Basic"]["Profile"] = "Church"
    user["Basic"]["ProfileDir"] = "Church"
save(user, root / "user.ini")

for profile in profiles:
    ini = profile / "basic.ini"
    cp = load(ini)
    for section, values in (
        ("General", {"Name": profile.name}),
        ("Audio", {"MonitoringDeviceId": DEVICE_ID, "MonitoringDeviceName": DEVICE_NAME}),
        ("Video", VIDEO),
        ("SimpleOutput", {"RecQuality": "Stream"}),
    ):
        if not cp.has_section(section):
            cp.add_section(section)
        for k, v in values.items():
            cp[section].setdefault(k, v) if section == "General" else cp[section].__setitem__(k, v)
    save(cp, ini)
    print(f"Monitoring device and video settings set in {ini}")
