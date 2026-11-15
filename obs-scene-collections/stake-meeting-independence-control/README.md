This Scene Collection is the control laptop for a Stake Conference. The camera pictures come from the main OBS over its WebSocket, not directly from the cameras. It is named "Stake Conference - Control (WebSocket)" in OBS. Use it with a 1920x1080 canvas and Studio Mode.

## How it works

- The **Camera Monitor** source is a browser source holding `monitor.html` (embedded in the collection, so there is nothing else to install). It connects to the main OBS (by default `192.168.108.4:4455`; see Settings), and about 10 times a second asks for a 960x540 screenshot of the main OBS's **Left Camera** and **Right Camera** scenes (Stake Meeting - Independence), or its **Joystick Left** and **Joystick Right** scenes when the main OBS has no Camera scenes (the older Independence collection). This is lower latency than RTSP because the main OBS is wired and the cameras' video has already been decoded there. It is a stream of still pictures, not full-motion video.
- Each camera's panel is outlined **green with PREVIEW** when the main OBS has a Left (or Right) scene in Preview, and **red with LIVE** when one is in Program. The scene names are listed under the pictures. The side comes from the word "Left" or "Right" in the scene name, so it follows preset scenes too ("Left Pulpit - P0"). Scenes with neither word (Sacrament, Blackmagic, Lower Thirds) light up neither panel.
- **Joystick Left** and **Joystick Right** here both show the Camera Monitor. Each has a hidden PTZ control source (VISCA over the network to 192.168.111.246 for Left and 192.168.111.245 for Right), so the scene you select decides which camera the PTZ dock steers.

## Settings

### Main OBS address, port and password

These are set in OBS, with no need to rebuild the collection. Right-click **Camera Monitor**, choose **Properties**, and edit the **Custom CSS** box:

```css
:root { --main-obs: "192.168.108.4"; --main-obs-port: "4455"; --main-obs-password: "2ne2-14"; }
```

Keep the quotes. Click **OK** and the monitor reconnects to the new address. The line under the pictures shows which address it is connecting to. Anything left out of the box falls back to the value above. The password is the default one from `setup-obs-flatpak.sh`.

A collections update (`tools/update-obs-collections`) puts the default back, so set it again afterwards.

### Everything else

The top of the script in `monitor.html` holds the two lists of scene names, the rate (`FPS`), the picture size and the JPEG quality. To change these, edit `monitor.html`, then put its base64 into the source's URL, or ask for the collection to be regenerated.

The camera addresses (192.168.111.245 and .246) are ordinary PTZ device settings. You can change them in OBS under the PTZ device settings.

## Load on the main OBS

About 20 screenshots a second, each about 60 KB (roughly 10 Mbit/s) and about 13 ms of OBS time. Lower `FPS` to 5 if the main OBS drops frames.
