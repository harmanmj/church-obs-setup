#!/usr/bin/env bash
# Get the latest scene collections from GitHub and replace every one OBS has. Run it as the broadcast user,
# without sudo. (Linux twin of update-obs-scene-collections.ps1.)
#
# Usage:  tools/update-obs-scene-collections.sh [--no-pull]
# Close OBS first. Changes made to these collections in OBS are replaced, without asking; each old file is kept
# as *.bak. Collections that did not come from this repo are left alone, none are added, and the collection OBS
# opens with stays the same. It installs nothing. If GitHub cannot be reached, nothing is changed.
#   --no-pull  skip GitHub and use the collections already in this checkout
# AUDIO_DEVICE=name forces a PulseAudio source.
set -euo pipefail

OBS_ID=com.obsproject.Studio
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_ROOT="$SCRIPT_DIR/../configs"

PULL=yes
for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=no ;;
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

check_obs_ready

if [ "$PULL" = yes ]; then
  if ! update_checkout "$(cd "$SCRIPT_DIR/.." && pwd)"; then
    echo "Could not get the latest scene collections from GitHub, so nothing changed. Check the internet connection, or use --no-pull to use the ones already on this computer." >&2
    exit 1
  fi
  # Carry on with the copy just pulled, as this script may have changed too.
  exec bash "$SCRIPT_DIR/update-obs-scene-collections.sh" --no-pull
fi

UPDATES=()
for dir in "$CONFIG_ROOT"/*/; do
  dir=${dir%/}
  for f in "$dir"/*.json; do
    if [ -e "$SCENES_DIR/$(basename "$f")" ]; then UPDATES+=("$dir"); break; fi
  done
done

OTHERS=()
for p in "$SCENES_DIR"/*.json; do
  [ -e "$p" ] || continue
  ours=no
  for dir in ${UPDATES[@]+"${UPDATES[@]}"}; do
    if [ -e "$dir/$(basename "$p")" ]; then ours=yes; fi
  done
  if [ "$ours" = no ]; then OTHERS+=("$(collection_name "$p")"); fi
done

if [ "${#UPDATES[@]}" -gt 0 ]; then
  pick_audio_device
  for dir in "${UPDATES[@]}"; do
    install_collection "$dir" "$SCENES_DIR"
    echo "Updated the '$(basename "$dir")' scene collection."
  done
else
  echo "OBS has no scene collections from this repo; nothing changed. Use tools/add-obs-scene-collection.sh to add one."
fi
if [ "${#OTHERS[@]}" -gt 0 ]; then
  list=$(printf ', %s' "${OTHERS[@]}")
  echo "Left alone (not from this repo): ${list:2}"
fi
if [ "${#UPDATES[@]}" -gt 0 ]; then warn_missing "$MUSIC_DIR" "${UPDATES[@]}"; fi
