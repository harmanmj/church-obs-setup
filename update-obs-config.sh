#!/usr/bin/env bash
# Download the latest version of this repository and install its OBS scene collections, without sudo.
# Runs as the person who uses OBS, never as root: git updates this folder, then tools/update-obs-collections.py
# installs every collection in obs-configuration/ (keeping the devices picked in OBS, with a .bak of each file it
# replaces). The scene collection that was active in OBS stays active. No software is installed or updated; that
# is done with sudo ./setup-obs-flatpak.sh --install.
# The "Update OBS" button (tools/obs-update-button.sh) runs this.
#
# Usage:  ./update-obs-config.sh [--no-pull]
#   --no-pull   use the files as they are, without downloading
# Close OBS first: it writes its scenes when it exits, which would undo the update.
set -euo pipefail

# Everything runs inside main(): bash reads a script while it runs it, and the download can replace this file.
main() {
  local OBS_ID=com.obsproject.Studio SCRIPT_DIR PULL=yes arg
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for arg in "$@"; do
    case "$arg" in
      --no-pull) PULL=no ;;
      *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
  done
  if [ "$EUID" -eq 0 ]; then
    echo "Run this as the person who uses OBS, without sudo." >&2
    exit 1
  fi
  if pgrep -u "$(id -u)" -f "$OBS_ID" >/dev/null; then
    echo "OBS is running. Close OBS and try again: it saves its scenes when it exits, which would undo the update." >&2
    exit 1
  fi

  if [ "$PULL" = yes ]; then
    local git=(git -C "$SCRIPT_DIR")
    if ! "${git[@]}" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      echo "$SCRIPT_DIR is not on a branch that follows GitHub, so updates cannot be downloaded." >&2
      echo "Running sudo ./setup-obs-flatpak.sh again fixes this." >&2
      exit 1
    fi
    echo "==> Downloading the latest version ($("${git[@]}" remote get-url origin), branch $("${git[@]}" symbolic-ref --short HEAD))"
    if ! "${git[@]}" fetch --quiet origin; then
      echo "Could not download the latest version. Check the internet connection and try again." >&2
      exit 1
    fi
    if ! "${git[@]}" merge --ff-only --quiet '@{u}'; then
      echo "$SCRIPT_DIR has local changes, so the latest version cannot be applied." >&2
      echo "Ask whoever looks after the broadcast computers to tidy it up (git status shows the changes)." >&2
      exit 1
    fi
    echo "Latest version: $("${git[@]}" log -1 --format='%h %s (%cs)')"
    # Run the version just downloaded.
    exec "$SCRIPT_DIR/update-obs-config.sh" --no-pull
  fi

  # The scene collection OBS opens on now. update-obs-collections.py leaves it as it is when it has no terminal to
  # ask in; it is set again afterwards in case the update renamed it (OBS finds it by its name).
  local OBS_DIR="$HOME/.var/app/$OBS_ID/config/obs-studio" ACTIVE_NAME ACTIVE_FILE
  ACTIVE_NAME=$(sed -n 's/^SceneCollection=//p' "$OBS_DIR/user.ini" 2>/dev/null | head -n 1 | tr -d '\r' || true)
  ACTIVE_FILE=$(sed -n 's/^SceneCollectionFile=//p' "$OBS_DIR/user.ini" 2>/dev/null | head -n 1 | tr -d '\r' || true)
  echo "Active scene collection: ${ACTIVE_NAME:-none}"

  echo "==> Installing the scene collections"
  python3 -I "$SCRIPT_DIR/tools/update-obs-collections.py" </dev/null

  local f
  if [ -n "$ACTIVE_FILE" ]; then
    for f in "$SCRIPT_DIR"/obs-configuration/*/*.json; do
      if [ "$(basename "$f" .json)" = "${ACTIVE_FILE%.json}" ]; then
        python3 -I "$SCRIPT_DIR/tools/set-obs-collection.py" "$OBS_DIR" "$f"
      fi
    done
  fi
  echo "==> All done."
}

main "$@"
exit
