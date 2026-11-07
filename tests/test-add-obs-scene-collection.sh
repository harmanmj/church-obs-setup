#!/usr/bin/env bash
# Test tools/add-obs-scene-collection.sh in a throwaway home folder, with stand-ins for flatpak, pactl and pgrep.
# Your real OBS settings are not touched. Run it without sudo: bash tests/test-add-obs-scene-collection.sh
# It exits non-zero if a check fails.
set -uo pipefail

TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/add-obs-scene-collection.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
OBS="$ROOT/home/.var/app/com.obsproject.Studio/config/obs-studio"
SCENES="$OBS/basic/scenes"
STAKE="$SCENES/stake-conference.json"
MUSIC="$ROOT/home/Documents/sacrament"
mkdir -p "$ROOT/bin" "$OBS" "$MUSIC"
printf '[Basic]\nSceneCollection=Untouched\n' > "$OBS/user.ini"
INI_BEFORE=$(cat "$OBS/user.ini")

# FAKE_NO_OBS, FAKE_NO_PLUGINS and FAKE_OBS_RUNNING pick what the stand-ins report.
cat > "$ROOT/bin/flatpak" <<'STUB'
#!/usr/bin/env bash
[ -z "${FAKE_NO_OBS:-}" ] || exit 1
[ -z "${FAKE_NO_PLUGINS:-}" ] || { [ "$1" = info ] && [ "$3" = com.obsproject.Studio ]; exit $?; }
[ "$1" != list ] || echo ca.secretlab.ptz
STUB
cat > "$ROOT/bin/pactl" <<'STUB'
#!/usr/bin/env bash
printf '1\talsa_output.pci.monitor\n2\talsa_input.usb-Creative_Sound_Blaster\n'
STUB
cat > "$ROOT/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[ -n "${FAKE_OBS_RUNNING:-}" ]
STUB
chmod +x "$ROOT"/bin/*

failed=0
check() { # description, then the test to run
  local what=$1; shift
  if "$@"; then echo "  ok    $what"; else echo "  FAIL  $what"; failed=$((failed + 1)); fi
}
add() { # options for the tool; VAR=value arguments before them set the stand-ins
  out=$(env HOME="$ROOT/home" PATH="$ROOT/bin:$PATH" "$@" 2>&1); code=$?
}
says() { grep -q -- "$1" <<<"$out"; }
lacks() { ! grep -q -- "$1" <<<"$out"; }
code_is() { [ "$code" -eq "$1" ]; }
code_not_0() { [ "$code" -ne 0 ]; }
no_match() { ! grep -q -- "$1" "$2"; }
same_ini() { [ "$(cat "$OBS/user.ini")" = "$INI_BEFORE" ]; }
no_baks() { ! ls "$SCENES"/stake-conference.json.*.bak >/dev/null 2>&1; }
one_bak() { [ "$(ls "$SCENES"/stake-conference.json.*.bak | wc -l)" -eq 1 ] && grep -q 'Changed in OBS' "$SCENES"/stake-conference.json.*.bak; }

echo "Adding a collection"
add bash "$TOOL" --config=stake-conference
check "exit code 0" code_is 0
check "the collection file is there" test -e "$STAKE"
check "no placeholders are left" no_match '@HOME@\|@AUDIO_DEVICE@' "$STAKE"
check "it uses the Sound Blaster" grep -q 'alsa_input.usb-Creative_Sound_Blaster' "$STAKE"
check "it points at the music folder" grep -q "$MUSIC/sacrament-playlist.mp3" "$STAKE"
check "it warns about the missing graphic" says 'sacrament-graphic.png is not in'
check "it warns about the missing playlist" says 'sacrament-playlist.mp3 is not in'
check "it finds the plugins" lacks 'plugin was not found'
check "the active collection is unchanged" same_ini

echo "Adding a second collection"
touch "$MUSIC/sacrament-graphic.png" "$MUSIC/sacrament-playlist.mp3"
add env AUDIO_DEVICE=my_mic bash "$TOOL" --config=dual-camera
check "exit code 0" code_is 0
check "both collections are there" test -e "$SCENES/dual-camera.json" -a -e "$STAKE"
check "AUDIO_DEVICE is used" grep -q 'my_mic' "$SCENES/dual-camera.json"
check "no sacrament warning once the files exist" lacks 'is not in'

echo "Adding it again keeps changes made in OBS"
echo '{"name":"Changed in OBS"}' > "$STAKE"
add bash "$TOOL" --config=stake-conference
check "exit code 0" code_is 0
check "it says nothing changed" says 'nothing changed'
check "the file is left alone" grep -q 'Changed in OBS' "$STAKE"
check "no backup was made" no_baks

echo "--force replaces it and keeps a backup"
add bash "$TOOL" --config=stake-conference --force
check "exit code 0" code_is 0
check "the file is replaced" no_match 'Changed in OBS' "$STAKE"
check "the old one is the backup" one_bak

echo "Things it should warn about or refuse"
add env FAKE_NO_PLUGINS=1 bash "$TOOL" --config=single-camera
check "missing plugins are warned about" says 'DistroAV plugin was not found'
check "as is obs-ptz" says 'obs-ptz plugin was not found'
check "Downstream Keyer is not needed by this one" lacks 'Downstream Keyer plugin'
add env FAKE_NO_PLUGINS=1 bash "$TOOL" --config=stake-conference --force
check "but is warned about for stake-conference" says 'Downstream Keyer plugin was not found'
rm -f "$SCENES/single-camera.json"
add bash "$TOOL" --config=no-such-collection
check "an unknown name fails" code_not_0
check "and says so" says 'No such configuration'
add bash "$TOOL" --bad-option
check "an unknown option fails" code_not_0
add env FAKE_NO_OBS=1 bash "$TOOL" --config=single-camera
check "it fails without OBS" says 'OBS is not installed'
add env FAKE_OBS_RUNNING=1 bash "$TOOL" --config=single-camera
check "it fails while OBS is running" says 'OBS is running'
check "and writes nothing" test ! -e "$SCENES/single-camera.json"
mv "$OBS/user.ini" "$OBS/user.ini.moved"
add bash "$TOOL" --config=single-camera
check "an account without OBS settings fails" says 'not set up'
mv "$OBS/user.ini.moved" "$OBS/user.ini"

if [ "$failed" -ne 0 ]; then echo "$failed check(s) failed."; exit 1; fi
echo "All checks passed."
