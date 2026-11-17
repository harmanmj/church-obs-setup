# Ubuntu Script Instructions

# Scene Collection information
  The setup script installs both Scene collections, Alkire and Quail - NDI and Independence Building - Hardware, and asks which one OBS should open on by default:
    1) alkire-and-quail
    2) independence-building
  Either one can be opened later from OBS's Scene Collection menu.
  The Alkire and Quail - NDI Scene Collection is intended for use in the Alkire and Quail Buildings. Its camera video comes over NDI. It also has the FreeShow lower thirds (Lower Thirds - Lyrics and Lower Thirds - Speakers, over NDI, with the Lyrics and Speaker Names downstream keyers). 
  These two scenes are not intended to be used on a weekly basis but are there in case they are needed for a meeting they are there and ready to go. NDI from Freeshow only works on a Windows or Mac computer which would need to be on the same network (or same windows computer) to work correctly. Freeshow is not installed as part of the setup script. Using these scenes requires docking the Downstream keyer Plugin.
  
  The Independence Building - Hardware Scene Collection is intended for use in the Independence Building (Stake Center). The camera video comes into the OBS computer through USB video capture devices: The House Left camera from a USB HDMI capture device ("USB3.0 Video") and The House Right Camera from a Blackmagic ATEM Mini. PTZ presets still move the cameras over the network. The blackmagic also captures the Rostrum HDMI out and can be used to insert video from the work room if needed.
  This scene collection also contains two additional scenes that are primarily used for stake broadcasts. Lower Thirds - Camera for overlaying camera video onto another source (using the Joystick - Left Scene) and a Blackmagic scene used when needing to capture other digital content into the stream instead of the camera. After setup, plug in both devices, open OBS and pick the Device on the "House Left - USB3.0 Video" and "House Right - ATEM Mini" sources (see obs-configuration/independence-building/README.md)

# Downstream Keyer
  `setup-obs-flatpak.sh` installs Downstream Keyer from the Flatpak attached to the newest release of a fork on GitHub (https://github.com/harmanmj/obs-downstream-keyer) instead of from Flathub. The fork adds the Load On Scene option (a keyer can be set to show only on the program scenes you choose) and Go Live / Go to Preview controls that work with Studio Mode.
  Each time the setup script runs, it downloads the newest release, installs it if Downstream Keyer is missing, and replaces it if it came from Flathub or from an older release. If the fork has no Flatpak published, the Flathub version is used. If the computer can't reach GitHub, the Downstream Keyer already installed is kept.

# First Time Ubuntu Install
  1. Open Terminal
  2. Run the following, then type 1 or 2 when it asks which scene collection should be the default
    ```terminal
    cd ~
    git clone https://github.com/smitchell7/church-obs-setup.git
    cd ~/church-obs-setup
    sudo ./setup-obs-flatpak.sh --pin-dock
    ```

# Update OBS Button (no terminal or password needed)
The setup script adds an **Update OBS** button to the app menu, and to the dock with `--pin-dock`. One click gets the latest scene collections from GitHub. It needs no sudo password and no terminal.
* It updates `~/church-obs-setup` from GitHub (the branch it is on), then installs every scene collection, the same way as [Updating Only the Scene Collections](#updating-only-the-scene-collections) below.
* The devices already picked in OBS are kept, and each replaced collection is saved as a dated `.bak` file.
* The scene collection that was active in OBS stays active.
* It does not install or update OBS or its plugins. For that, see [Updating configuration on Existing Installations](#updating-configuration-on-existing-installations).

OBS must be closed first. If something goes wrong, the button shows the details. The output of the last run is in `~/.cache/church-obs-update.log`.

To make the button follow a different repository or branch, run the setup script from a different copy, for example:
```terminal
sudo UPDATE_REPO=https://github.com/harmanmj/church-obs-setup.git UPDATE_BRANCH=obs-update-button ./setup-obs-flatpak.sh
```

# Updating configuration on Existing Installations
No sudo is needed to get the latest version of this repository. The setup script makes `~/church-obs-setup` belong to you. If it was cloned with `sudo git clone` and `git pull` fails with "Permission denied", run the setup script once (below) and it is fixed.
* **Update** (type 1 or 2 when it asks which scene collection should be the default)
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    sudo ./setup-obs-flatpak.sh
    ```

# Updating Only the Scene Collections
The **Update OBS** button does this in one click. To do it in a terminal instead:

Use this when only the scene collections have changed. It installs the newest version of every scene collection in `obs-configuration/` without running the rest of the setup (no software is installed). The devices already picked in OBS (the cameras, the USB Audio microphone and the FreeShow NDI sources) are kept, and each collection it replaces is saved as a `.bak` file. It also builds the notch filter plugins used on USB Audio if they are missing, and makes sure OBS can find them. It turns on Studio Mode. If the repo's OBS window layout (`obs-configuration/obs-layout.ini`) has changed since this computer last got it, it installs that layout; otherwise the layout is left as it was arranged in OBS. Close OBS, then run the following in a normal terminal, without sudo:
* **Update the Scene Collections** (type the number of the scene collection OBS should open on when it asks)
    ```terminal
    cd ~/church-obs-setup
    git checkout main
    git pull
    python3 tools/update-obs-collections.py
    ```

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal terminal, without sudo. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```terminal
    cd ~/church-obs-setup
    python3 tools/set-obs-video.py
    ```
