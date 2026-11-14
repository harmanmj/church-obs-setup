# Windows Script Instructions

# Scene Collection information
  The setup script installs both Scene collections, Alkire and Quail Building - NDI and Independence Building - Hardware, and asks which one OBS should open on by default:
    1) alkire-quail-building
    2) independence-building
  Either one can be opened later from OBS's Scene Collection menu.
  The Alkire and Quail Building - NDI Scene Collection is intended for use in the Alkire and Quail Buildings. Its camera video comes over NDI. It also has the FreeShow lower thirds (Lower Thirds - Lyrics and Lower Thirds - Speakers, over NDI, with the Lyrics and Speaker Names downstream keyers).
  The Independence Building - Hardware Scene Collection is intended for use in the Independence Building (Stake Center). The camera video comes into the OBS computer through USB video capture devices: House Left from a Blackmagic ATEM Mini and House Right from a USB HDMI capture device ("USB3.0 Video"). PTZ presets still move the cameras over the network. It also has the stake conference scenes: the FreeShow lower thirds over NDI, the camera Video Overlay and a Blackmagic scene. After setup, plug in both devices, open OBS and pick the Device on the "House Left - ATEM Mini" and "House Right - USB3.0 Video" sources (see configs/independence-building/README.md)

# Downstream Keyer
The setup script installs Downstream Keyer from the newest release of a fork on GitHub (https://github.com/harmanmj/obs-downstream-keyer), which adds the Load On Scene option: a keyer can be set to show only on the program scenes you choose. If the fork has no release published, it installs exeldro's release (https://github.com/exeldro/obs-downstream-keyer) instead. Each time the setup script runs, it installs the newest release over the one already there.


# First Time Windows Install
  1. Open **PowerShell as administrator** (Start, type `powershell`, right-click > Run as administrator)
  2. Run the following, then type 1 or 2 when it asks which scene collection should be the default
    ```powershell
    cd $env:TEMP
    irm https://raw.githubusercontent.com/smitchell7/church-obs-setup/HEAD/setup-obs-windows.ps1 -OutFile setup-obs-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1
    ```

# Updating configuration on Existing Installations
* **Update** (type 1 or 2 when it asks which scene collection should be the default)
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1
    ```

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal PowerShell. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\tools\set-obs-video.ps1
    ```
