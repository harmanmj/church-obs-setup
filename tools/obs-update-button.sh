#!/usr/bin/env bash
# The "Update OBS" button (app menu and dock). One click downloads the latest version of ~/church-obs-setup and
# installs its scene collections (update-obs-config.sh). The scene collection that was active stays active, and
# the devices picked in OBS are kept. A replaced scene collection is kept as a dated .bak file.
# Runs as the logged-in user: no password and no terminal. Progress and results are dialog boxes (zenity).
# It does not install or update software; that still needs sudo ./setup-obs-flatpak.sh --install.
set -uo pipefail

# Everything runs inside main(): bash reads a script while it runs it, and the download can replace this file.
main() {
  local TITLE="Update OBS" REPO_DIR LOG pid
  REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  LOG="${XDG_CACHE_HOME:-$HOME/.cache}/church-obs-update.log"
  mkdir -p "$(dirname "$LOG")"

  # The dock starts apps on a single click, so a double click starts this twice: the second one just stops.
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/church-obs-update.lock"
  flock -n 9 || return

  if pgrep -u "$(id -u)" -f com.obsproject.Studio >/dev/null; then
    zenity --warning --title="$TITLE" --width=400 --text="OBS is open. Close OBS, then press Update OBS again."
    return
  fi

  # The update runs in the background, so closing the progress window does not stop it halfway.
  : > "$LOG"
  ( "$REPO_DIR/update-obs-config.sh" >"$LOG" 2>&1; echo "EXIT=$?" >>"$LOG" ) &
  pid=$!
  (
    while kill -0 "$pid" 2>/dev/null; do
      echo "# $(grep -v '^EXIT=' "$LOG" | tail -n 1 | tr -d '<>&' | cut -c1-100)"
      sleep 1
    done
    echo 100
  ) | zenity --progress --pulsate --auto-close --no-cancel --width=620 --title="$TITLE" \
      --text="Downloading the latest scene collections…"
  wait "$pid"

  if [ "$(sed -n 's/^EXIT=//p' "$LOG" | tail -n 1)" = 0 ]; then
    local active
    active=$(sed -n "s/^OBS will open with the '\(.*\)' scene collection\.$/\1/p; s/^Active scene collection: //p" "$LOG" | tail -n 1)
    zenity --info --title="$TITLE" --width=380 \
      --text="Done. The scene collections are up to date.\n\nOBS will open with: ${active:-the same scene collection as before}"
  else
    zenity --error --title="$TITLE" --width=420 \
      --text="The update did not finish. The details are shown next: take a photo of them for whoever looks after the broadcast computers."
    zenity --text-info --title="$TITLE: details" --width=800 --height=500 --filename="$LOG"
  fi
}

main "$@"
exit
