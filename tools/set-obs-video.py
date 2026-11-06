#!/usr/bin/env python3
"""Set OBS's video in every profile: 1920x1080 canvas and output, 30 fps, recording quality "Same as stream".

Usage: set-obs-video.py [OBS_CONFIG_DIR] [--if-first-setup]
OBS_CONFIG_DIR defaults to this user's Flatpak OBS. Close OBS first: it writes its settings when it exits.
The setup script uses --if-first-setup, so changes made in OBS survive a re-run. Run without it to reset the video.
FirstRun=true marks the setup as done, and also skips OBS's Auto-Configuration Wizard.
"""
import configparser
import pathlib
import shutil
import subprocess
import sys

OBS_ID = "com.obsproject.Studio"
# The scene collections are laid out for a 1920x1080 canvas.
VIDEO = {"BaseCX": "1920", "BaseCY": "1080", "OutputCX": "1920", "OutputCY": "1080", "FPSType": "0", "FPSCommon": "30"}


def load(path):
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str  # OBS keys are case-sensitive
    if path.exists():
        cp.read(path, encoding="utf-8-sig")
    return cp


def save(cp, path):
    with path.open("w", encoding="utf-8") as f:
        cp.write(f, space_around_delimiters=False)


def section(cp, name):
    if not cp.has_section(name):
        cp.add_section(name)
    return cp[name]


args = [a for a in sys.argv[1:] if a != "--if-first-setup"]
first_setup_only = "--if-first-setup" in sys.argv
root = pathlib.Path(args[0]) if args else pathlib.Path.home() / ".var/app" / OBS_ID / "config/obs-studio"

user = load(root / "user.ini")
if first_setup_only and user.get("General", "FirstRun", fallback="") == "true":
    print("Keeping the OBS video settings already there.")
    sys.exit()
if not first_setup_only and shutil.which("pgrep") and subprocess.run(["pgrep", "-f", OBS_ID], capture_output=True).returncode == 0:
    sys.exit("OBS is running. Close it and run this again.")

profiles = sorted(p for p in (root / "basic" / "profiles").glob("*") if p.is_dir())
if not profiles:
    sys.exit(f"No OBS profiles in {root}. Run the setup script first.")
for profile in profiles:
    ini = profile / "basic.ini"
    cp = load(ini)
    section(cp, "Video").update(VIDEO)
    section(cp, "SimpleOutput")["RecQuality"] = "Stream"
    save(cp, ini)
    print(f"OBS video ({profile.name}): 1920x1080 canvas and output, 30 fps, recording same as stream")

section(user, "General")["FirstRun"] = "true"
save(user, root / "user.ini")
