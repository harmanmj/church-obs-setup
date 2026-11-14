# Windows Script Instructions

# Scene Collection information
  The setup script installs both Scene collections, Alkire and Quail - NDI and Independence Building - Hardware, and asks which one OBS should open on by default:
    1) alkire-and-quail
    2) independence-building
  Either one can be opened later from OBS's Scene Collection menu.
  The Alkire and Quail - NDI Scene Collection is intended for use in the Alkire and Quail Buildings. Its camera video comes over NDI. It also has the FreeShow lower thirds (Lower Thirds - Lyrics and Lower Thirds - Speakers, over NDI, with the Lyrics and Speaker Names downstream keyers). 
  These two scenes are not intended to be used on a weekly basis but are there in case they are needed for a meeting they are there and ready to go. NDI from Freeshow only works on a Windows or Mac computer which would need to be on the same network (or same windows computer) to work correctly. Freeshow is not installed as part of the setup script. Using these scenes requires docking the Downstream keyer Plugin.
  
  The Independence Building - Hardware Scene Collection is intended for use in the Independence Building (Stake Center). The camera video comes into the OBS computer through USB video capture devices: The House Left camera from a USB HDMI capture device ("USB3.0 Video") and The House Right Camera from a Blackmagic ATEM Mini. PTZ presets still move the cameras over the network. The blackmagic also captures the Rostrum HDMI out and can be used to insert video from the work room if needed.
  This scene collection also contains two additional scenes that are primarily used for stake broadcasts. Lower Thirds - Camera for overlaying camera video onto another source (using the Joystick - Left Scene) and a Blackmagic scene used when needing to capture other digital content into the stream instead of the camera. After setup, plug in both devices, open OBS and pick the Device on the "House Left - USB3.0 Video" and "House Right - ATEM Mini" sources (see configs/independence-building/README.md)

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

# Updating Only the Scene Collections
Use this when only the scene collections have changed. It installs the newest Alkire and Quail - NDI and Independence Building - Hardware collections without running the rest of the setup (nothing else is installed or changed). The devices already picked in OBS (the cameras, the USB Audio microphone and the FreeShow NDI sources) are kept, and each collection it replaces is saved as a `.bak` file. Close OBS, then run the following in a normal PowerShell (not as administrator):
* **Update the Scene Collections** (type 1 or 2 when it asks which scene collection should be the default)
    ```powershell
    cd c:\church-obs-setup
    git pull
    powershell -ExecutionPolicy Bypass -File .\tools\update-obs-collections.ps1
    ```

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal PowerShell. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\tools\set-obs-video.ps1
    ```
