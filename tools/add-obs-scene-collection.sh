#!/usr/bin/env bash
# Add one scene collection to OBS, and nothing else. Run it as the broadcast user, without sudo.
# (Linux twin of add-obs-scene-collection.ps1.)
#
# Usage:  tools/add-obs-scene-collection.sh [--config=NAME] [--force]
# Close OBS first. It installs nothing, does not update this repo, and leaves the collection OBS opens with as
# it is: the new one appears in OBS's Scene Collection menu. Only collections in this checkout can be added.
#   --config=NAME  the collection in configs/NAME to add (without it, it asks)
#   --force        replace the collection if it is already there, keeping the old one as *.bak
#                  (without it a collection already there is left alone, so scenes changed in OBS survive)
# AUDIO_DEVICE=name forces a PulseAudio source.
set -euo pipefail

OBS_ID=com.obsproject.Studio
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_ROOT="$SCRIPT_DIR/../configs"

CONFIG_CHOICE=ask
FORCE=no
for arg in "$@"; do
  case "$arg" in
    --config=*) CONFIG_CHOICE=${arg#--config=} ;;
    --force) FORCE=yes ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [ "$EUID" -eq 0 ]; then
  echo "Run this without sudo, as the person who uses OBS." >&2
  exit 1
fi
TARGET_USER=$(id -un)
TARGET_HOME=$HOME
as_user() { "$@"; }
source "$SCRIPT_DIR/obs-collection.sh"

OBS_DIR="$TARGET_HOME/.var/app/$OBS_ID/config/obs-studio"
SCENES_DIR="$OBS_DIR/basic/scenes"
MUSIC_DIR="$TARGET_HOME/Documents/sacrament"

if ! flatpak info --system "$OBS_ID" >/dev/null 2>&1; then
  echo "OBS is not installed. Run setup-obs-flatpak.sh first." >&2
  exit 1
fi
if [ ! -e "$OBS_DIR/user.ini" ]; then
  echo "OBS is not set up for $TARGET_USER. Sign in as the person who uses OBS, or run setup-obs-flatpak.sh first." >&2
  exit 1
fi
if pgrep -u "$TARGET_USER" -f "$OBS_ID" >/dev/null; then
  echo "OBS is running. Close it and run this again." >&2
  exit 1
fi

mapfile -t CONFIGS < <(cd "$CONFIG_ROOT" && ls -d */ | tr -d /)

is_installed() {
  local f
  for f in "$CONFIG_ROOT/$1"/*.json; do
    [ -e "$SCENES_DIR/$(basename "$f")" ] && return 0
  done
  return 1
}

if [ "$CONFIG_CHOICE" = ask ]; then
  echo "Which scene collection should be added?"
  for name in "${CONFIGS[@]}"; do
    if is_installed "$name"; then echo "  $name (already added)"; else echo "  $name"; fi
  done
  select choice in "${CONFIGS[@]}"; do
    [ -n "$choice" ] && { CONFIG_CHOICE=$choice; break; }
    echo "Pick a number from the list."
  done
fi
if [ ! -d "$CONFIG_ROOT/$CONFIG_CHOICE" ]; then
  echo "No such configuration: $CONFIG_CHOICE (have: ${CONFIGS[*]})" >&2
  exit 1
fi

if is_installed "$CONFIG_CHOICE" && [ "$FORCE" = no ]; then
  echo "The '$CONFIG_CHOICE' scene collection is already there; nothing changed. Use --force to replace it."
  exit 0
fi

pick_audio_device
install_collection "$CONFIG_ROOT/$CONFIG_CHOICE" "$SCENES_DIR"
echo "Installed the '$CONFIG_CHOICE' scene collection. Pick it from OBS's Scene Collection menu."

# Every collection uses these; OBS opens without them, but with those sources missing.
flatpak info --system "$OBS_ID.Plugin.DistroAV" >/dev/null 2>&1 ||
  echo "WARNING: the DistroAV plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
flatpak list --system --columns=application 2>/dev/null | grep -qi 'ptz' ||
  echo "WARNING: the obs-ptz plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
if grep -qi downstream "$CONFIG_ROOT/$CONFIG_CHOICE"/*.json && ! flatpak info --system "$OBS_ID.Plugin.DownstreamKeyer" >/dev/null 2>&1; then
  echo "WARNING: the Downstream Keyer plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
fi
for f in sacrament-graphic.png sacrament-playlist.mp3; do
  [ -e "$MUSIC_DIR/$f" ] || echo "WARNING: $f is not in $MUSIC_DIR. Run setup-obs-flatpak.sh to make it." >&2
done
