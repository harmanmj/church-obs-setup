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
# Fixed notches for two steady tones measured on the Independence Building microphone (Q 12, about 500 and 1100 Hz wide).
gcc -O2 -fPIC -shared -fvisibility=hidden -Wall -Wextra -DNOTCH_HZ=6381.0 -DNOTCH_Q=12.0 -DNOTCH_NAME='"Notch 6381 Hz"' -DNOTCH_ID=0x4e363338 \
  -o "$HOME/.vst/Notch6381.so" "$HERE/tone_notch_vst.c" -lm
echo "Installed $HOME/.vst/Notch6381.so"
gcc -O2 -fPIC -shared -fvisibility=hidden -Wall -Wextra -DNOTCH_HZ=13623.0 -DNOTCH_Q=12.0 -DNOTCH_NAME='"Notch 13623 Hz"' -DNOTCH_ID=0x4e313336 \
  -o "$HOME/.vst/Notch13623.so" "$HERE/tone_notch_vst.c" -lm
echo "Installed $HOME/.vst/Notch13623.so"
