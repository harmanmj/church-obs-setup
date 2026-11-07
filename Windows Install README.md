# Windows Script Instructions

# Scene Collection information
  There are three total Scene collections you can install - single camera, dual camera and stake conference - depending on the number of cameras installed in your building and if you need the additional scenes used for stake conference broadcasts
  use the code labeled below for the scene collection you want to install
  The single camera Scene Collection is intended for use in the Alkire and Quail Building
  The Dual Camera Scene Collection is intended for use in the Independence Building (Stake Center)
  The Stake Conference Scene Collection is intended for use for meetings where an additional computer will be generating and sending overlay graphics to OBS using NDI. It is based on the Dual Camera Scene Collection. If it is being used in the Alkire or Quail buildings for a meeting ONLY the scenes labeled left will work correctly

# First Time Windows Install
  1. Open **PowerShell as administrator** (Start, type `powershell`, right-click > Run as administrator)
  2. Run one of the following depending on required camera configuration for your building
* **Single Camera Configuration**
    ```powershell
    cd $env:TEMP
    irm https://raw.githubusercontent.com/smitchell7/church-obs-setup/HEAD/setup-obs-windows.ps1 -OutFile setup-obs-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config single-camera
    ```
* **Dual Camera Configuration**
    ```powershell
    cd $env:TEMP
    irm https://raw.githubusercontent.com/smitchell7/church-obs-setup/HEAD/setup-obs-windows.ps1 -OutFile setup-obs-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config dual-camera
    ```
* **Stake Conference Camera Configuration**
    ```powershell
    cd $env:TEMP
    irm https://raw.githubusercontent.com/smitchell7/church-obs-setup/HEAD/setup-obs-windows.ps1 -OutFile setup-obs-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config stake-conference
    ```

# Updating configuration on Existing Installations
Run these from **PowerShell as administrator** (Start, type `powershell`, right-click > Run as administrator).
* **Single Camera Configuration**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config single-camera
    ```
* **Dual Camera Configuration**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config dual-camera
    ```
* **Stake Conference Camera Configuration**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\setup-obs-windows.ps1 -Config stake-conference
    ```
# Adding a Scene Collection
To add a scene collection you do not currently have, close OBS and run the following in a normal PowerShell (not as administrator). It shows the scene collections already in OBS, then a numbered list of the ones you can add. It first gets the latest list from GitHub; if it cannot, it warns you and uses the scene collections already on this computer. Type one number, or several separated by spaces (for example `1 2`) to add more than one at a time. It only adds the ones you pick, and nothing is installed. Afterwards it lists the scene collections in OBS so you can pick which one OBS opens with; enter 0 to keep the current one.
* **Add a Scene Collection**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\tools\add-obs-scene-collection.ps1
    ```
If the command is not found, this computer has an older copy of the setup. Run the update above once, then this will work.

# Updating All Scene Collections
To get the latest scene collections from GitHub and replace every one in OBS, close OBS and run the following in a normal PowerShell (not as administrator). Scene collections you made yourself in OBS are left alone, and none are added.

**Changes made to these scene collections in OBS are replaced without asking**, including any NDI sources you picked by hand, such as the lower thirds. Each old file is saved as a .bak file in `%APPDATA%\obs-studio\basic\scenes`. Plug in the USB audio input first, as the audio input is picked again.
* **Update All Scene Collections**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\tools\update-obs-scene-collections.ps1
    ```
If GitHub cannot be reached, nothing is changed. Add `-NoPull` to the end of the command to use the scene collections already on this computer instead.

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal PowerShell. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```powershell
    cd c:\church-obs-setup
    powershell -ExecutionPolicy Bypass -File .\tools\set-obs-video.ps1
    ```
