This Scene Collection is the control laptop for a Stake Conference. The camera pictures come from the main OBS over its WebSocket, not directly from the cameras. It is named "Stake Conference - Control (WebSocket)" in OBS. Use it with a 1920x1080 canvas and Studio Mode.

## How it works

- The **Camera Monitor** source is a browser source holding `monitor.html` (embedded in the collection, so there is nothing else to install). It connects to the main OBS at `192.168.108.4:4455`, and about 10 times a second asks for a 960x540 screenshot of the main OBS's **Joystick Left** and **Joystick Right** scenes. This is lower latency than RTSP because the main OBS is wired and the cameras' video has already been decoded there. It is a stream of still pictures, not full-motion video.
- Each camera's panel is outlined **green with PREVIEW** when the main OBS has a Left (or Right) scene in Preview, and **red with LIVE** when one is in Program. The scene names are listed under the pictures. The side comes from the word "Left" or "Right" in the scene name, so it follows preset scenes too ("Left Pulpit - P0"). Scenes with neither word (Sacrament, Blackmagic, Lower Thirds) light up neither panel.
- **Joystick Left** and **Joystick Right** here both show the Camera Monitor. Each has a hidden PTZ control source (VISCA over the network to 192.168.111.246 for Left and 192.168.111.245 for Right), so the scene you select decides which camera the PTZ dock steers.

## Settings

The top of the script in `monitor.html` holds the host, port, password, the two scene names, the rate (`FPS`), the picture size and the JPEG quality. To change one, edit the source's URL in OBS (it is a `data:` URL, so it is easier to edit `monitor.html`, then paste its base64 back in) or ask for the collection to be regenerated. The WebSocket password is the default one from `setup-obs-flatpak.sh`.

## Load on the main OBS

About 20 screenshots a second, each about 60 KB (roughly 10 Mbit/s) and about 13 ms of OBS time. Lower `FPS` to 5 if the main OBS drops frames.
