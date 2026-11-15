This Scene Collection is the control laptop for a Stake Conference with two RTSP cameras. It is named "Stake Conference - Control" in OBS. Use it with a 1920x1080 canvas and Studio Mode.

## Scenes

| Scene | Camera | RTSP address | PTZ (VISCA) |
|---|---|---|---|
| **Joystick Left** | PTZ Camera Left | `rtsp://192.168.111.246:554/1` | 192.168.111.246:5678 |
| **Joystick Right** | PTZ Camera Right | `rtsp://192.168.111.245:554/1` | 192.168.111.245:5678 |

Both cameras use RTSP over TCP with an 8 MB network buffer, to avoid the picture artifacting that UDP packet loss causes. If the picture lags too much, lower the buffer or switch back to UDP in the source properties.

Each scene shows one camera full-screen, with sound from "USB Audio", and has a hidden PTZ control source so the PTZ dock steers that camera. Put one scene in Preview and the other in Program with Studio Mode to see and steer both.

Check which physical camera is which before relying on the addresses; other collections in this repo have Left and Right the other way round.
