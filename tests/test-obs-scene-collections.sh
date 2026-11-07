#!/usr/bin/env bash
# Test tools/add-obs-scene-collection.sh and update-obs-scene-collections.sh in a throwaway home folder, with
# stand-ins for flatpak, pactl and pgrep.
# Your real OBS settings are not touched. Run it without sudo: bash tests/test-obs-scene-collections.sh
# It exits non-zero if a check fails.
set -uo pipefail

TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/add-obs-scene-collection.sh"
UPDATE="$(dirname "$TOOL")/update-obs-scene-collections.sh"
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
printf '#!/usr/bin/env bash\necho "$@" > "%s/active"\n' "$ROOT" > "$ROOT/bin/python3"
cat > "$ROOT/bin/pactl" <<'STUB'
#!/usr/bin/env bash
printf '1\talsa_output.pci.monitor\n2\talsa_input.usb-Creative_Sound_Blaster\n'
STUB
cat > "$ROOT/bin/pgrep" <<'STUB'
#!/usr/bin/env bash
[ -n "${FAKE_OBS_RUNNING:-}" ] && [[ " $* " == *" -x obs "* ]]
STUB
printf '#!/usr/bin/env bash\n[ -z "${FAKE_NOT_OURS:-}" ] || { echo "fatal: detected dubious ownership in repository" >&2; exit 128; }\nexec "%s" "$@"\n' "$(command -v git)" > "$ROOT/bin/git"
chmod +x "$ROOT"/bin/*

failed=0
check() { # description, then the test to run
  local what=$1; shift
  if "$@"; then echo "  ok    $what"; else echo "  FAIL  $what"; failed=$((failed + 1)); fi
}
add() { # options for the tool; VAR=value arguments before them set the stand-ins
  out=$(env HOME="$ROOT/home" PATH="$ROOT/bin:$PATH" "$@" 2>&1 <<<"${ANSWER:-}"); code=$?
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
add bash "$TOOL" --no-pull --config=stake-conference
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
add env AUDIO_DEVICE=my_mic bash "$TOOL" --no-pull --config=dual-camera
check "exit code 0" code_is 0
check "both collections are there" test -e "$SCENES/dual-camera.json" -a -e "$STAKE"
check "AUDIO_DEVICE is used" grep -q 'my_mic' "$SCENES/dual-camera.json"
check "no sacrament warning once the files exist" lacks 'is not in'

echo "Adding it again keeps changes made in OBS"
echo '{"name":"Changed in OBS"}' > "$STAKE"
add bash "$TOOL" --no-pull --config=stake-conference
check "exit code 0" code_is 0
check "it says nothing changed" says 'nothing changed'
check "the file is left alone" grep -q 'Changed in OBS' "$STAKE"
check "no backup was made" no_baks

echo "--force replaces it and keeps a backup"
add bash "$TOOL" --no-pull --config=stake-conference --force
check "exit code 0" code_is 0
check "the file is replaced" no_match 'Changed in OBS' "$STAKE"
check "the old one is the backup" one_bak

echo "The menu reads what OBS already has"
DUAL="$SCENES/dual-camera.json"
rm -f "$DUAL"
printf '{\n    "name": "Made in OBS"\n}\n' > "$SCENES/made-in-obs.json"
printf '{\n    "name": "Single Camera"\n}\n' > "$SCENES/Single_Camera.json"
ANSWER=$'9\n0' add bash "$TOOL" --no-pull
check "exit code 0" code_is 0
check "it lists what is in OBS" says 'Already in OBS:.*Made in OBS'
check "it offers what is missing" says ') Dual Camera'
check "it does not offer what is there" lacks ') Stake Conference'
check "it knows a collection by name, whatever the file" lacks ') Single Camera$'
check "a bad answer asks again and 0 cancels" test ! -e "$DUAL"
ANSWER=1 add bash "$TOOL" --no-pull
check "a number adds that collection" test -e "$DUAL"

echo "Updating replaces what OBS has from this repo"
echo '{"name":"edited"}' > "$STAKE"
echo '{"name":"edited"}' > "$DUAL"
add bash "$UPDATE" --no-pull
check "exit code 0" code_is 0
check "the first is replaced" no_match 'edited' "$STAKE"
check "the second is replaced" no_match 'edited' "$DUAL"
check "each old file is kept" test "$(grep -l edited "$SCENES"/*.bak | wc -l)" -eq 2
check "collections made in OBS are left alone" grep -q 'Made in OBS' "$SCENES/made-in-obs.json"
check "and it says so" says 'Left alone.*Made in OBS'
check "nothing new is added" test ! -e "$SCENES/single-camera.json"
check "the active collection is unchanged" same_ini
add env FAKE_OBS_RUNNING=1 bash "$UPDATE" --no-pull
check "it fails while OBS is running" says 'OBS is running'
add bash "$UPDATE" --bad-option
check "an unknown option fails" code_not_0

echo "When everything is there"
rm -f "$SCENES/made-in-obs.json" "$SCENES/Single_Camera.json"
for dir in "$(dirname "$TOOL")"/../configs/*/; do add bash "$TOOL" --no-pull --config="$(basename "$dir")"; done
add bash "$TOOL" --no-pull
check "the menu says so instead of asking" says 'already in OBS'
for f in "$SCENES"/*.json; do
  case "$f" in "$STAKE"|"$DUAL") ;; *) rm -f "$f" ;; esac
done

echo "Adding several at once"
SINGLE="$SCENES/single-camera.json"
both_there() { [ -e "$DUAL" ] && [ -e "$SINGLE" ]; }
neither_there() { [ ! -e "$DUAL" ] && [ ! -e "$SINGLE" ]; }
audio_once() { [ "$(grep -c 'Audio input for OBS' <<<"$out")" -eq 1 ]; }
dual_once() { [ "$(grep -c "Installed the 'dual-camera'" <<<"$out")" -eq 1 ]; }
rm -f "$DUAL" "$STAKE"
ANSWER='1 2' add bash "$TOOL" --no-pull
check "two numbers add both" both_there
check "and leave the third" test ! -e "$STAKE"
check "it picks the audio input once" audio_once
rm -f "$DUAL" "$SINGLE"
ANSWER='1,1, 2' add bash "$TOOL" --no-pull
check "commas work" both_there
check "and a repeat counts once" dual_once
rm -f "$DUAL" "$SINGLE"
ANSWER=$'1 99\n0 1\nabc 1\n0' add bash "$TOOL" --no-pull
check "a bad number in the list adds nothing" neither_there
check "and cancelling after it exits cleanly" code_is 0
add bash "$TOOL" --no-pull --config=dual-camera,no-such-collection
check "a mistyped name fails" code_not_0
check "and names the bad one" says 'No such configuration: no-such-collection'
check "and adds nothing" test ! -e "$DUAL"
add bash "$TOOL" --no-pull --config=dual-camera,stake-conference
check "--config takes several" test -e "$DUAL" -a -e "$STAKE"
echo '{"name":"edited"}' > "$DUAL"
add bash "$TOOL" --no-pull --config=dual-camera,single-camera
check "a list adds what is missing" test -e "$SINGLE"
check "and keeps what is there" grep -q edited "$DUAL"
check "and says so" says "'dual-camera' scene collection is already there"
rm -f "$SINGLE"
add bash "$TOOL" --no-pull --config=dual-camera,stake-conference --force
check "--force replaces every one in the list" no_match 'edited' "$DUAL"

echo "Choosing the active collection after adding"
rm -f "$DUAL" "$ROOT/active"
ANSWER=$'1\n0' add bash "$TOOL" --no-pull
check "it lists what is in OBS" says ') Stake Conference'
check "with a way to keep the current one" says 'keep the current one'
check "0 keeps the active collection" test ! -e "$ROOT/active"
rm -f "$DUAL"
ANSWER=$'1\n1' add bash "$TOOL" --no-pull
check "a number makes that one active" grep -q 'dual-camera.json' "$ROOT/active"
sed -i 's/^SceneCollection=.*/&\nSceneCollectionFile=dual-camera.json/' "$OBS/user.ini"
rm -f "$DUAL" "$ROOT/active"
ANSWER=$'1\n0' add bash "$TOOL" --no-pull
check "it marks the active one" says 'Dual Camera (active now)'
printf '%s\n' "$INI_BEFORE" > "$OBS/user.ini"
rm -f "$DUAL"
ANSWER=$'1 2\n99\n3' add bash "$TOOL" --no-pull
check "it also asks after adding several, and a bad number asks again" grep -q 'stake-conference.json' "$ROOT/active"
rm -f "$DUAL" "$SINGLE" "$ROOT/active"
add bash "$TOOL" --no-pull --config=dual-camera
check "--config does not ask" lacks 'keep the current one'
check "and changes nothing" test ! -e "$ROOT/active"

mv "$SCENES" "$SCENES.moved"
add bash "$UPDATE" --no-pull
check "updating with none from this repo changes nothing" says 'nothing changed'
mv "$SCENES.moved" "$SCENES"

echo "Updating gets the latest first, from a stand-in for GitHub"
REPO=$(cd "$(dirname "$TOOL")/.." && pwd)
GIT_ID=(-c user.name=test -c user.email=test@example.com)
git init -q --bare "$ROOT/origin.git"
git clone -q -c core.autocrlf=false "$ROOT/origin.git" "$ROOT/work" 2>/dev/null
mkdir -p "$ROOT/work/configs"
cp -r "$REPO/tools" "$ROOT/work/"
cp -r "$REPO/configs/dual-camera" "$ROOT/work/configs/"
git -C "$ROOT/work" add -A 2>/dev/null
git -C "$ROOT/work" "${GIT_ID[@]}" commit -q -m first
git -C "$ROOT/work" push -q origin HEAD
git clone -q -c core.autocrlf=false "$ROOT/origin.git" "$ROOT/checkout"
sed -i 's/"name": "Dual Camera"/"name": "Dual Camera Pulled"/' "$ROOT/work/configs/dual-camera/dual-camera.json"
git -C "$ROOT/work" "${GIT_ID[@]}" commit -q -am second
git -C "$ROOT/work" push -q origin HEAD
PULLED="$ROOT/checkout/tools/update-obs-scene-collections.sh"

add bash "$PULLED"
check "exit code 0" code_is 0
check "it says which version it is at" says 'At [0-9a-f]* second'
check "OBS gets the newer collection" grep -q 'Dual Camera Pulled' "$DUAL"

mkdir "$ROOT/work/configs/brand-new"
printf '{\n    "name": "Brand New"\n}\n' > "$ROOT/work/configs/brand-new/brand-new.json"
git -C "$ROOT/work" add -A 2>/dev/null
git -C "$ROOT/work" "${GIT_ID[@]}" commit -q -m third
git -C "$ROOT/work" push -q origin HEAD
ADD_PULLED="$ROOT/checkout/tools/add-obs-scene-collection.sh"
ANSWER=1 add bash "$ADD_PULLED"
check "the menu offers a collection that is only on GitHub" says ') Brand New'
check "and adding gets it" test -e "$SCENES/brand-new.json"
check "and says which version it is at" says 'At [0-9a-f]* third'
rm -f "$SCENES/brand-new.json"

git -C "$ROOT/checkout" remote set-url origin "$ROOT/gone.git"
add bash "$ADD_PULLED" --config=brand-new
check "adding still works if GitHub cannot be reached" test -e "$SCENES/brand-new.json"
check "and warns about it" says 'using the ones already on this computer'
check "with no ownership hint, as that is not the problem" lacks 'sudo chown'
rm -f "$SCENES/brand-new.json"
add env FAKE_NOT_OURS=1 bash "$ADD_PULLED" --config=brand-new
check "a folder owned by another account gets the hint" says 'sudo chown'
rm -f "$SCENES/brand-new.json"

echo '{"name":"edited"}' > "$DUAL"
add bash "$PULLED"
check "it fails if GitHub cannot be reached" code_not_0
check "and says nothing changed" says 'nothing changed'
check "and leaves the collection alone" grep -q 'edited' "$DUAL"
add bash "$PULLED" --no-pull
check "--no-pull works without GitHub" grep -q 'Dual Camera Pulled' "$DUAL"

echo "Things it should warn about or refuse"
add env FAKE_NO_PLUGINS=1 bash "$TOOL" --no-pull --config=single-camera
check "missing plugins are warned about" says 'DistroAV plugin was not found'
check "as is obs-ptz" says 'obs-ptz plugin was not found'
check "Downstream Keyer is not needed by this one" lacks 'Downstream Keyer plugin'
add env FAKE_NO_PLUGINS=1 bash "$TOOL" --no-pull --config=stake-conference --force
check "but is warned about for stake-conference" says 'Downstream Keyer plugin was not found'
rm -f "$SCENES/single-camera.json"
add bash "$TOOL" --no-pull --config=no-such-collection
check "an unknown name fails" code_not_0
check "and says so" says 'No such configuration'
add bash "$TOOL" --no-pull --bad-option
check "an unknown option fails" code_not_0
add env FAKE_NO_OBS=1 bash "$TOOL" --no-pull --config=single-camera
check "it fails without OBS" says 'OBS is not installed'
add env FAKE_OBS_RUNNING=1 bash "$TOOL" --no-pull --config=single-camera
check "it fails while OBS is running" says 'OBS is running'
check "and writes nothing" test ! -e "$SCENES/single-camera.json"
mv "$OBS/user.ini" "$OBS/user.ini.moved"
add bash "$TOOL" --no-pull --config=single-camera
check "an account without OBS settings fails" says 'not set up'
mv "$OBS/user.ini.moved" "$OBS/user.ini"

if [ "$failed" -ne 0 ]; then echo "$failed check(s) failed."; exit 1; fi
echo "All checks passed."
