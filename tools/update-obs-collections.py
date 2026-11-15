#!/usr/bin/env python3
"""Update just the OBS scene collections on this computer from this repo.

Installs every collection in obs-scene-collections/ the same way setup-obs-flatpak.sh does, without running the rest of
the setup (no software installs, no audio or other OBS settings). The Windows twin is
tools/update-obs-collections.ps1.

Usage (as the person who uses OBS, not with sudo; close OBS first):
    python3 tools/update-obs-collections.py [--default alkire-and-quail|independence-building]

- Each file it replaces is saved next to it as *.bak.
- Keeps what was already picked in OBS, by source name: the "USB Audio" microphone, capture devices and
  NDI senders. A new "USB Audio" gets the input the setup script would pick (Sound Blaster, else USB, ...).
- Builds the notch filter plugins (tools/hum-notch-vst/build.sh) into ~/.vst if any are missing, and sets
  VST_PATH for the OBS Flatpak so it finds them.
- Asks which collection OBS opens on, like the setup script (1 alkire-and-quail, 2 independence-building);
  --default answers up front. Run without a terminal to ask in, it leaves OBS's current one.
"""
import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import time

REPO = pathlib.Path(__file__).resolve().parent.parent
OBS_DIR = pathlib.Path.home() / ".var/app/com.obsproject.Studio/config/obs-studio"
SCENES = OBS_DIR / "basic" / "scenes"

parser = argparse.ArgumentParser(description="Update just the OBS scene collections from this repo.")
parser.add_argument("--default", help="the collection OBS opens on (a folder name in obs-scene-collections/)")
args = parser.parse_args()

if subprocess.run(["pgrep", "-f", "com.obsproject.Studio"], capture_output=True).returncode == 0:
    sys.exit("Close OBS first, then run this again.")
# Which collection OBS opens on: the same menu, in the same order, as setup-obs-flatpak.sh.
found = sorted(p.name for p in (REPO / "obs-scene-collections").iterdir() if p.is_dir())
names = [n for n in ("alkire-and-quail", "independence-building") if n in found]
names += [n for n in found if n not in names]
configs = [REPO / "obs-scene-collections" / n for n in names]
if args.default:
    if args.default not in names:
        sys.exit(f"No collection named {args.default} (have: {', '.join(names)})")
elif sys.stdin.isatty() and names:
    print("Which scene collection should OBS open on by default?")
    for i, n in enumerate(names, 1):
        print(f"  {i}) {n}")
    while True:
        answer = input("Number: ").strip()
        if answer.isdigit() and 1 <= int(answer) <= len(names):
            args.default = names[int(answer) - 1]
            break


def pick_microphone():
    """The input setup-obs-flatpak.sh would pick: the Sound Blaster, else a USB input, else any real input."""
    try:
        out = subprocess.run(["pactl", "list", "short", "sources"], capture_output=True, text=True).stdout
    except FileNotFoundError:
        return "default"
    sources = [line.split("\t")[1] for line in out.splitlines()
               if "\t" in line and not line.split("\t")[1].endswith(".monitor")]
    for test in (lambda s: "sound_blaster" in s.lower(),
                 lambda s: s.lower().startswith("alsa_input.usb"),
                 lambda s: s.startswith("alsa_input.")):
        found = [s for s in sources if test(s)]
        if found:
            return found[0]
    return "default"


microphone = None
SCENES.mkdir(parents=True, exist_ok=True)
print(f"Scene collections from {REPO / 'obs-scene-collections'}")
for config in configs:
    for src in sorted(config.glob("*.json")):
        dest = SCENES / src.name
        collection = json.loads(src.read_text(encoding="utf-8").replace("@HOME@", str(pathlib.Path.home())))
        old = {}
        if dest.exists():
            try:
                old = {s["name"]: s for s in json.loads(dest.read_text(encoding="utf-8"))["sources"]}
            except (ValueError, KeyError):
                pass
        kept = []
        for s in collection["sources"]:
            settings = s.setdefault("settings", {})
            before = old.get(s["name"], {}).get("settings", {})
            if s.get("id") == "pulse_input_capture" and settings.get("device_id") == "@AUDIO_DEVICE@":
                if before.get("device_id") and before["device_id"] != "@AUDIO_DEVICE@":
                    settings["device_id"] = before["device_id"]
                    kept.append(s["name"])
                else:
                    microphone = microphone or pick_microphone()
                    settings["device_id"] = microphone
            elif s.get("id") == "v4l2_input" and not settings.get("device_id") and before.get("device_id"):
                settings["device_id"] = before["device_id"]
                kept.append(s["name"])
            elif s.get("id") == "ndi_source" and not settings.get("ndi_source_name") and before.get("ndi_source_name"):
                settings["ndi_source_name"] = before["ndi_source_name"]
                kept.append(s["name"])
        if dest.exists():
            shutil.copy2(dest, dest.with_name(f"{dest.name}.{time.strftime('%Y%m%d-%H%M%S')}.bak"))
        dest.write_text(json.dumps(collection, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Updated {src.name} ({collection['name']})")
        if kept:
            print(f"    kept from OBS: {', '.join(kept)}")

# The notch filters on "USB Audio" load VST plugins from ~/.vst. Build any that are missing and point the OBS
# Flatpak at that folder (VST_PATH), as the setup script does; without either, OBS skips those filters.
VST_DIR = pathlib.Path.home() / ".vst"
plugins = {pathlib.PurePosixPath(path).name for c in configs for f in c.glob("*.json")
           for path in re.findall(r'"plugin_path":\s*"([^"]+)"', f.read_text(encoding="utf-8"))}
missing = sorted(name for name in plugins if not (VST_DIR / name).exists())
if missing:
    if shutil.which("gcc"):
        print(f"Building the notch filter plugins into {VST_DIR} (missing: {', '.join(missing)})")
        subprocess.run(["bash", str(REPO / "tools" / "hum-notch-vst" / "build.sh")], check=False)
    else:
        print(f"WARNING: {', '.join(missing)} not in {VST_DIR} and gcc is missing, so the notch filters on "
              "'USB Audio' will not load. Run: sudo apt-get install -y gcc && bash tools/hum-notch-vst/build.sh")
if plugins and shutil.which("flatpak"):
    override = subprocess.run(["flatpak", "override", "--user", "--show", "com.obsproject.Studio"],
                              capture_output=True, text=True).stdout
    if f"VST_PATH={VST_DIR}" not in override:
        result = subprocess.run(["flatpak", "override", "--user", f"--env=VST_PATH={VST_DIR}", "com.obsproject.Studio"])
        if result.returncode == 0:
            print(f"Set VST_PATH={VST_DIR} for OBS, so it loads the notch filter plugins")
        else:
            print("WARNING: could not set VST_PATH for OBS; the notch filters on 'USB Audio' will not load.")

if args.default:
    collection = next((REPO / "obs-scene-collections" / args.default).glob("*.json"))
    subprocess.run([sys.executable, "-I", str(REPO / "tools" / "set-obs-collection.py"), str(OBS_DIR), str(collection)],
                   check=True)
