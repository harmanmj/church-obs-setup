# Pick the audio input and install a scene collection. (Linux twin of obs-collection.ps1.)
# Sourced by setup-obs-flatpak.sh (as root) and tools/add-obs-scene-collection.sh (as the broadcast user); both set
# TARGET_USER, TARGET_HOME and as_user first.

# Audio comes from a USB input (the Sound Blaster where there is one). Use AUDIO_DEVICE=name to force a
# PulseAudio source, else pick the Sound Blaster, else any USB input, else the system default.
pick_audio_device() {
  if [ -z "${AUDIO_DEVICE:-}" ]; then
    local target_uid sources
    target_uid=$(id -u "$TARGET_USER")
    sources=$(as_user env XDG_RUNTIME_DIR="/run/user/$target_uid" pactl list short sources 2>/dev/null | cut -f2 | grep -v '\.monitor$' || true)
    AUDIO_DEVICE=$(grep -i 'sound_blaster' <<<"$sources" | head -1 || true)
    [ -n "$AUDIO_DEVICE" ] || AUDIO_DEVICE=$(grep -i '^alsa_input\.usb' <<<"$sources" | head -1 || true)
    # Else any real input, by name: "default" could one day be OBS Mic, which would feed OBS back into itself.
    [ -n "$AUDIO_DEVICE" ] || AUDIO_DEVICE=$(grep '^alsa_input\.' <<<"$sources" | head -1 || true)
    [ -n "$AUDIO_DEVICE" ] || AUDIO_DEVICE=default
  fi
  echo "Audio input for OBS: $AUDIO_DEVICE (change it on the 'USB Audio' source in OBS if this is wrong)"
}

# By process name: Flatpak's sandbox keeps the app id out of OBS's command line, so pgrep -f cannot see it.
obs_running() {
  pgrep -u "$TARGET_USER" -x obs >/dev/null
}

# Stop unless OBS can be changed for this account: installed, set up and closed. Needs OBS_ID and OBS_DIR.
check_obs_ready() {
  if ! flatpak info --system "$OBS_ID" >/dev/null 2>&1; then
    echo "OBS is not installed. Run setup-obs-flatpak.sh first." >&2
    exit 1
  fi
  if [ ! -e "$OBS_DIR/user.ini" ]; then
    echo "OBS is not set up for $TARGET_USER. Sign in as the person who uses OBS, or run setup-obs-flatpak.sh first." >&2
    exit 1
  fi
  if obs_running; then
    echo "OBS is running. Close it and run this again." >&2
    exit 1
  fi
}

# update_checkout REPO_DIR: get the latest of this repo from GitHub.
update_checkout() {
  local out
  if ! out=$(git -C "$1" pull --quiet --ff-only 2>&1); then
    echo "$out" >&2
    if grep -q -E 'dubious ownership|Permission denied' <<<"$out"; then
      echo "This folder belongs to another account. Run this once to fix that: sudo chown -R $TARGET_USER:$TARGET_USER $1" >&2
    fi
    return 1
  fi
  echo "At $(git -C "$1" log -1 --format='%h %s')"
}

# collection_name FILE: the top-level "name", which OBS writes with a four-space indent.
collection_name() {
  sed -n '/^    "name":/{s/^    "name": *"\([^"]*\)".*/\1/p;q}' "$1"
}

# in_obs CONFIG_DIR SCENES_DIR: by name as well as file, as OBS names the file itself when a collection
# is imported or made there.
in_obs() {
  local f p name
  for f in "$1"/*.json; do
    [ ! -e "$2/$(basename "$f")" ] || return 0
    name=$(collection_name "$f")
    for p in "$2"/*.json; do
      if [ -e "$p" ] && [ "$(collection_name "$p")" = "$name" ]; then return 0; fi
    done
  done
  return 1
}

# warn_missing MUSIC_DIR CONFIG_DIR...: what these collections need that only the full setup can add.
warn_missing() {
  local music=$1 dir f
  shift
  # Every collection uses these; OBS opens without them, but with those sources missing.
  flatpak info --system "$OBS_ID.Plugin.DistroAV" >/dev/null 2>&1 ||
    echo "WARNING: the DistroAV plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
  flatpak list --system --columns=application 2>/dev/null | grep -qi 'ptz' ||
    echo "WARNING: the obs-ptz plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
  for dir in "$@"; do
    if grep -qi downstream "$dir"/*.json; then
      flatpak info --system "$OBS_ID.Plugin.DownstreamKeyer" >/dev/null 2>&1 ||
        echo "WARNING: the Downstream Keyer plugin was not found. Run setup-obs-flatpak.sh to install it." >&2
      break
    fi
  done
  for f in sacrament-graphic.png sacrament-playlist.mp3; do
    [ -e "$music/$f" ] || echo "WARNING: $f is not in $music. Run setup-obs-flatpak.sh to make it." >&2
  done
}

# install_collection CONFIG_DIR SCENES_DIR: an existing file that differs is kept as *.bak.
install_collection() {
  local f dest rendered
  as_user mkdir -p "$2"
  for f in "$1"/*.json; do
    dest="$2/$(basename "$f")"
    rendered=$(mktemp)
    sed -e "s|@HOME@|$TARGET_HOME|g" -e "s|@AUDIO_DEVICE@|$AUDIO_DEVICE|g" "$f" > "$rendered"
    if [ -e "$dest" ] && cmp -s "$rendered" "$dest"; then
      echo "$(basename "$f") is already up to date."
    else
      if [ -e "$dest" ]; then
        as_user cp "$dest" "$dest.$(date +%Y%m%d-%H%M%S).bak"
        echo "$(basename "$f") is updated; the old one is kept as a .bak file."
      fi
      as_user tee "$dest" < "$rendered" >/dev/null
    fi
    rm -f "$rendered"
  done
}
