#!/usr/bin/env bash
# Replace every scene collection OBS has with the copy in this repo. Run it as the broadcast user, without sudo.
# (Linux twin of update-obs-scene-collections.ps1.)
#
# Usage:  tools/update-obs-scene-collections.sh
# Close OBS first. Changes made to these collections in OBS are replaced, without asking; each old file is kept
# as *.bak. Collections that did not come from this repo are left alone, none are added, and the collection OBS
# opens with stays the same. It installs nothing and does not update this repo, so it uses the collections in
# this checkout.
# AUDIO_DEVICE=name forces a PulseAudio source.
set -euo pipefail

OBS_ID=com.obsproject.Studio
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_ROOT="$SCRIPT_DIR/../configs"

for arg in "$@"; do
  echo "Unknown option: $arg" >&2
  exit 1
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
