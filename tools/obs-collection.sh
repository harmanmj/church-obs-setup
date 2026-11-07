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
      [ -e "$dest" ] && as_user cp "$dest" "$dest.$(date +%Y%m%d-%H%M%S).bak"
      as_user tee "$dest" < "$rendered" >/dev/null
    fi
    rm -f "$rendered"
  done
}
