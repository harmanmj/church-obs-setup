# Ubuntu Script Instructions

# Scene Collection information
  There are three total Scene collections you can install - single camera, dual camera and stake conference - depending on the number of cameras installed in your building and if you need the additional scenes used for stake conference broadcasts
  use the code labeled below for the scene collection you want to install
  The single camera Scene Collection is intended for use in the Alkire and Quail Building
  The Dual Camera Scene Collection is intended for use in the Independence Building (Stake Center)
  The Stake Conference Scene Collection is intended for use for meetings where an additional computer will be generating and sending overlay graphics to OBS using NDI. It is based on the Dual Camera Scene Collection. If it is being used in the Alkire or Quail buildings for a meeting ONLY the scenes labeled right will work correctly. Both Stake Conference collections also have a Blackmagic scene for a Blackmagic ATEM Mini connected by USB; after setup, pick the ATEM Mini as the Device on the "ATEM Mini" source in OBS (see configs/stake-conference/README.md)

# Downstream Keyer
  `setup-obs-flatpak.sh` installs Downstream Keyer from the Flatpak attached to the newest release of a fork on GitHub (https://github.com/harmanmj/obs-downstream-keyer) instead of from Flathub. The fork adds the Load On Scene option (a keyer can be set to show only on the program scenes you choose) and Go Live / Go to Preview controls that work with Studio Mode.
  Each time the setup script runs, it downloads the newest release, installs it if Downstream Keyer is missing, and replaces it if it came from Flathub or from an older release. If the fork has no Flatpak published, the Flathub version is used. If the computer can't reach GitHub, the Downstream Keyer already installed is kept.

# First Time Ubuntu Install
  1. Open Terminal
  2. Run one of the following depending on required camera configuration for your building
* **Single Camera Configuration**
    ```terminal
    cd ~
    sudo git clone https://github.com/smitchell7/church-obs-setup.git
    cd ~/church-obs-setup
    sudo ./setup-obs-flatpak.sh --config=single-camera --pin-dock
    ```
* **Dual Camera Configuration**
    ```terminal
    cd ~
    sudo git clone https://github.com/smitchell7/church-obs-setup.git
    cd ~/church-obs-setup
    sudo ./setup-obs-flatpak.sh --config=dual-camera --pin-dock
    ```
* **Stake Conference Camera Configuration**
    ```terminal
    cd ~
    sudo git clone https://github.com/smitchell7/church-obs-setup.git
    cd ~/church-obs-setup
    sudo ./setup-obs-flatpak.sh --config=stake-conference --pin-dock
    ```

# Updating configuration on Existing Installations
* **The first time you do this, you may need to start with the following command**
    ```terminal
    cd ~/church-obs-setup
    sudo chown -R $USER:$USER ~/church-obs-setup
    ```
* **Single Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=single-camera
    ```
* **Dual Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=dual-camera
    ```
* **Stake Conference Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=stake-conference
    ```
If you need to add one of the scene collections you do not currently have, run the update script for the scene collection you want to add to your computer

# RTSP Scene Collections
If the cameras' NDI video does not work, use the RTSP version of your scene collection. It is the same collection, named "... - RTSP" in OBS (the NDI version is "... - NDI"), but the camera video comes from `rtsp://<camera IP>:554/1` instead of NDI. It is installed alongside the NDI version, so you can switch between them in OBS's Scene Collection menu. Close OBS, then run the one for your building:
* **Single Camera Configuration (RTSP)**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=single-camera-rtsp
    ```
* **Dual Camera Configuration (RTSP)**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=dual-camera-rtsp
    ```
* **Stake Conference Camera Configuration (RTSP)**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=stake-conference-rtsp
    ```

# Independence Building - Hardware Scene Collection
Based on the Stake Conference collection, for the Independence Building where the camera video comes into the OBS computer through USB video capture devices instead of over NDI: House Left from a Blackmagic ATEM Mini and House Right from a USB HDMI capture device ("USB3.0 Video"). It is named "Independence Building - Hardware" in OBS and is installed alongside the other collections. PTZ presets still move the cameras over the network. After setup, plug in both devices, open OBS and pick the Device on the "House Left - ATEM Mini" and "House Right - USB3.0 Video" sources (see configs/independence-building/README.md). Close OBS, then run:
* **Independence Building - Hardware Configuration**
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh --config=independence-building
    ```

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal terminal, without sudo. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```terminal
    cd ~/church-obs-setup
    python3 tools/set-obs-video.py
    ```
