# Ubuntu Script Instructions

# Scene Collection information
  The setup script installs both Scene collections, Alkire and Quail - NDI and Independence Building - Hardware, and asks which one OBS should open on by default:
    1) alkire-and-quail
    2) independence-building
  Either one can be opened later from OBS's Scene Collection menu.
  The Alkire and Quail - NDI Scene Collection is intended for use in the Alkire and Quail Buildings. Its camera video comes over NDI. It also has the FreeShow lower thirds (Lower Thirds - Lyrics and Lower Thirds - Speakers, over NDI, with the Lyrics and Speaker Names downstream keyers).
  The Independence Building - Hardware Scene Collection is intended for use in the Independence Building (Stake Center). The camera video comes into the OBS computer through USB video capture devices: House Left from a Blackmagic ATEM Mini and House Right from a USB HDMI capture device ("USB3.0 Video"). PTZ presets still move the cameras over the network. It also has the stake conference scenes: the FreeShow lower thirds over NDI, the camera Video Overlay and a Blackmagic scene. After setup, plug in both devices, open OBS and pick the Device on the "House Left - ATEM Mini" and "House Right - USB3.0 Video" sources (see configs/independence-building/README.md)

# Downstream Keyer
  `setup-obs-flatpak.sh` installs Downstream Keyer from the Flatpak attached to the newest release of a fork on GitHub (https://github.com/harmanmj/obs-downstream-keyer) instead of from Flathub. The fork adds the Load On Scene option (a keyer can be set to show only on the program scenes you choose) and Go Live / Go to Preview controls that work with Studio Mode.
  Each time the setup script runs, it downloads the newest release, installs it if Downstream Keyer is missing, and replaces it if it came from Flathub or from an older release. If the fork has no Flatpak published, the Flathub version is used. If the computer can't reach GitHub, the Downstream Keyer already installed is kept.

# First Time Ubuntu Install
  1. Open Terminal
  2. Run the following, then type 1 or 2 when it asks which scene collection should be the default
    ```terminal
    cd ~
    sudo git clone https://github.com/smitchell7/church-obs-setup.git
    cd ~/church-obs-setup
    sudo ./setup-obs-flatpak.sh --pin-dock
    ```

# Updating configuration on Existing Installations
* **The first time you do this, you may need to start with the following command**
    ```terminal
    cd ~/church-obs-setup
    sudo chown -R $USER:$USER ~/church-obs-setup
    ```
* **Update** (type 1 or 2 when it asks which scene collection should be the default)
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh
    ```

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal terminal, without sudo. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```terminal
    cd ~/church-obs-setup
    python3 tools/set-obs-video.py
    ```
