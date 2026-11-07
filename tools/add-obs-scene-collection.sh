#!/usr/bin/env bash
# Add one scene collection to OBS, and nothing else. Run it as the broadcast user, without sudo.
# (Linux twin of add-obs-scene-collection.ps1.)
#
# Usage:  tools/add-obs-scene-collection.sh [--config=NAME] [--force] [--no-pull]
# Close OBS first. It gets the latest collections from GitHub (or, if it cannot, uses the ones in this checkout),
# lists the collections OBS already has and asks which of the others to add. It installs nothing and leaves the
# collection OBS opens with as it is: the new one appears in OBS's Scene Collection menu.
#   --config=NAME  the collection in configs/NAME to add, instead of asking
#   --no-pull      skip GitHub and use the collections already in this checkout
#   --force        replace the collection if it is already there, keeping the old one as *.bak
#                  (without it a collection already there is left alone, so scenes changed in OBS survive)
# AUDIO_DEVICE=name forces a PulseAudio source.
set -euo pipefail

OBS_ID=com.obsproject.Studio
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_ROOT="$SCRIPT_DIR/../configs"

CONFIG_CHOICE=ask
FORCE=no
PULL=yes
for arg in "$@"; do
  case "$arg" in
    --config=*) CONFIG_CHOICE=${arg#--config=} ;;
    --force) FORCE=yes ;;
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
  if update_checkout "$(cd "$SCRIPT_DIR/.." && pwd)"; then
    # Carry on with the copy just pulled, as this script may have changed too.
    exec bash "$SCRIPT_DIR/add-obs-scene-collection.sh" --no-pull "$@"
  fi
  echo "WARNING: could not get the latest scene collections from GitHub; using the ones already on this computer." >&2
fi

CONFIGS=()
for dir in "$CONFIG_ROOT"/*/; do
  dir=${dir%/}
  if compgen -G "$dir/*.json" >/dev/null; then CONFIGS+=("$(basename "$dir")"); fi
done

if [ "$CONFIG_CHOICE" = ask ]; then
  PRESENT=()
  for p in "$SCENES_DIR"/*.json; do
    if [ -e "$p" ]; then PRESENT+=("$(collection_name "$p")"); fi
  done
  if [ "${#PRESENT[@]}" -gt 0 ]; then
    list=$(printf ', %s' "${PRESENT[@]}")
    echo "Already in OBS: ${list:2}"
  fi
  CHOICES=()
  for name in "${CONFIGS[@]}"; do
    if [ "$FORCE" = yes ] || ! in_obs "$CONFIG_ROOT/$name" "$SCENES_DIR"; then CHOICES+=("$name"); fi
  done
  if [ "${#CHOICES[@]}" -eq 0 ]; then
    echo "Every scene collection in this repo is already in OBS. To replace them, run tools/update-obs-scene-collections.sh."
    exit 0
  fi
  echo "Scene collections you can add:"
  for i in "${!CHOICES[@]}"; do
    echo "  $((i + 1))) $(collection_name "$CONFIG_ROOT/${CHOICES[$i]}/${CHOICES[$i]}.json")"
  done
  echo "  0) cancel"
  while read -r -p "Enter the number of the scene collection you want to add to OBS: " n; do
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -le "${#CHOICES[@]}" ]; then
      [ "$n" -ne 0 ] || exit 0
      CONFIG_CHOICE=${CHOICES[$((n - 1))]}
      break
    fi
  done
  [ "$CONFIG_CHOICE" != ask ] || exit 0   # no more input
fi
if ! compgen -G "$CONFIG_ROOT/$CONFIG_CHOICE/*.json" >/dev/null; then
  echo "No such configuration: $CONFIG_CHOICE (have: ${CONFIGS[*]})" >&2
  exit 1
fi

if in_obs "$CONFIG_ROOT/$CONFIG_CHOICE" "$SCENES_DIR" && [ "$FORCE" = no ]; then
  echo "The '$CONFIG_CHOICE' scene collection is already there; nothing changed. Use --force to replace it."
  exit 0
fi

pick_audio_device
install_collection "$CONFIG_ROOT/$CONFIG_CHOICE" "$SCENES_DIR"
echo "Installed the '$CONFIG_CHOICE' scene collection. Pick it from OBS's Scene Collection menu."
warn_missing "$MUSIC_DIR" "$CONFIG_ROOT/$CONFIG_CHOICE"
