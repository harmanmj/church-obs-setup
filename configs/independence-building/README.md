This Scene Collection, for the Independence Building, is the Stake Conference collection with the camera video coming from video capture devices plugged into the OBS computer by USB, instead of over NDI. It is named "Independence Building - Hardware" in OBS.

## Cameras

| Source | Device | Scenes |
|---|---|---|
| **House Left - USB3.0 Video** | USB HDMI capture device (shows as "USB3.0 Video") | every "Left ..." scene and Joystick Left |
| **House Right - ATEM Mini** | Blackmagic ATEM Mini (shows as "Blackmagic Design") | every "Right ..." scene, Joystick Right and Blackmagic |

PTZ control is unchanged: the preset scenes still move the cameras over the network (VISCA), so the cameras must stay on the network as well as being plugged into the capture devices.

The setup scripts don't choose the capture devices. On each computer that uses this collection, plug in both devices, open OBS, double-click each source above and pick its **Device**.

Sound comes from the "USB Audio" source, as in the other collections. The capture devices' own audio is muted.

## Differences from the old Stake Conference collection

- The camera sources are video capture devices instead of NDI.
- There is no separate "ATEM Mini" source, because the ATEM Mini is now the House Right camera and two sources can't use the same capture device at once. The **Blackmagic** scene, just after Sacrament and above the Lower Thirds scenes, shows the House Right - ATEM Mini source with sound from "USB Audio".
- The "Lower Thirds - Camera" scene, which the **Video Overlay** keyer shows, has only the House Left camera (Joystick Left, the USB3.0 capture device), at 25% in the bottom-right corner. House Right isn't in it.
- The FreeShow lower thirds still come over NDI.
