#!/usr/bin/env bash
# Builds the Hum Notch and Squeal Notch VST 2.x plugins and installs them to ~/.vst/, where OBS (flatpak included) finds
# them. Run as the normal user (no sudo). Needs gcc (sudo apt-get install -y gcc). Restart OBS afterwards, then
# on the microphone source: Filters > + > VST 2.x Plug-in > HumNotch (and SquealNotch for a ~10 kHz whine).
# The eye icon turns each one on and off.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$HOME/.vst"
gcc -O2 -fPIC -shared -fvisibility=hidden -Wall -Wextra -o "$HOME/.vst/HumNotch.so" "$HERE/hum_notch_vst.c" -lm
echo "Installed $HOME/.vst/HumNotch.so"
gcc -O2 -fPIC -shared -fvisibility=hidden -Wall -Wextra -o "$HOME/.vst/SquealNotch.so" "$HERE/squeal_notch_vst.c" -lm
echo "Installed $HOME/.vst/SquealNotch.so"
