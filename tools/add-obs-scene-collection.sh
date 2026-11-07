#!/usr/bin/env bash
# Add scene collections to OBS, and nothing else. Run it as the broadcast user, without sudo.
# (Linux twin of add-obs-scene-collection.ps1.)
#
# Usage:  tools/add-obs-scene-collection.sh [--config=NAME[,NAME...]] [--force] [--no-pull]
# Close OBS first. It gets the latest collections from GitHub (or, if it cannot, uses the ones in this checkout),
# lists the collections OBS already has and asks which of the others to add. The new ones appear in OBS's Scene
# Collection menu. After adding from the menu it asks which collection OBS should open with; with --config that
# stays as it is. It installs nothing.
#   --config=NAME  the collection in configs/NAME to add, instead of asking; separate several with commas
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
  SELECTED=()
  while read -r -p "Enter the numbers of the scene collections you want to add to OBS, separated by spaces: " n; do
    IFS=', ' read -r -a picks <<<"$n"
    valid=yes
    [ "${#picks[@]}" -gt 0 ] || valid=no
    for p in ${picks[@]+"${picks[@]}"}; do
      if ! [[ "$p" =~ ^[0-9]{1,3}$ ]] || [ "$((10#$p))" -gt "${#CHOICES[@]}" ]; then
        valid=no
      elif [ "$((10#$p))" -eq 0 ] && [ "${#picks[@]}" -gt 1 ]; then
        valid=no   # 0 cancels, so it only counts on its own
      fi
    done
    [ "$valid" = yes ] || continue
    [ "$((10#${picks[0]}))" -ne 0 ] || exit 0
    for p in "${picks[@]}"; do
      name=${CHOICES[$((10#$p - 1))]}
      if [[ " ${SELECTED[*]:-} " != *" $name "* ]]; then SELECTED+=("$name"); fi
    done
    break
  done
  [ "${#SELECTED[@]}" -gt 0 ] || exit 0   # no more input
else
  IFS=',' read -r -a SELECTED <<<"$CONFIG_CHOICE"
fi

# Check them all first, so a mistyped name adds nothing.
for name in "${SELECTED[@]}"; do
  if ! compgen -G "$CONFIG_ROOT/$name/*.json" >/dev/null; then
    echo "No such configuration: $name (have: ${CONFIGS[*]})" >&2
    exit 1
  fi
done

ADDING=()
for name in "${SELECTED[@]}"; do
  if in_obs "$CONFIG_ROOT/$name" "$SCENES_DIR" && [ "$FORCE" = no ]; then
    echo "The '$name' scene collection is already there; nothing changed. Use --force to replace it."
  else
    ADDING+=("$CONFIG_ROOT/$name")
  fi
done
[ "${#ADDING[@]}" -gt 0 ] || exit 0

pick_audio_device
for dir in "${ADDING[@]}"; do
  install_collection "$dir" "$SCENES_DIR"
  echo "Installed the '$(basename "$dir")' scene collection. Pick it from OBS's Scene Collection menu."
done
warn_missing "$MUSIC_DIR" "${ADDING[@]}"

if [ "$CONFIG_CHOICE" = ask ]; then
  INSTALLED=("$SCENES_DIR"/*.json)
  ACTIVE=$(sed -n 's/^SceneCollectionFile=//p' "$OBS_DIR/user.ini" | tr -d '\r' | head -1)
  echo "Scene collections in OBS:"
  for i in "${!INSTALLED[@]}"; do
    note=
    if [ "$(basename "${INSTALLED[$i]}")" = "$ACTIVE" ]; then note=" (active now)"; fi
    echo "  $((i + 1))) $(collection_name "${INSTALLED[$i]}")$note"
  done
  echo "  0) keep the current one"
  while read -r -p "Enter the number of the scene collection you want to make active: " n; do
    [ -n "$n" ] || exit 0
    if [[ "$n" =~ ^[0-9]{1,3}$ ]] && [ "$((10#$n))" -le "${#INSTALLED[@]}" ]; then
      [ "$((10#$n))" -ne 0 ] || exit 0
      python3 -I "$SCRIPT_DIR/set-obs-collection.py" "$OBS_DIR" "${INSTALLED[$((10#$n - 1))]}"
      break
    fi
  done
fi
