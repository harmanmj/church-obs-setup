# Ubuntu Script Instructions

# Scene Collection information
  There are three total Scene collections you can install - single camera, dual camera and stake conference - depending on the number of cameras installed in your building and if you need the additional scenes used for stake conference broadcasts
  use the code labeled below for the scene collection you want to install
  The single camera Scene Collection is intended for use in the Alkire and Quail Building
  The Dual Camera Scene Collection is intended for use in the Independence Building (Stake Center)
  The Stake Conference Scene Collection is intended for use for meetings where an additional computer will be generating and sending overlay graphics to OBS using NDI. It is based on the Dual Camera Scene Collection. If it is being used in the Alkire or Quail buildings for a meeting ONLY the scenes labeled left will work correctly

# Downstream Keyer
  `setup-obs-flatpak.sh` installs Downstream Keyer from the Flatpak bundle in the `vendor` folder instead of from Flathub. The bundle is built from the `load-on-scene` branch of a fork on GitHub (https://github.com/harmanmj/obs-downstream-keyer), which adds the Load On Scene option: a keyer can be set to show only on the program scenes you choose.
  Each time the setup script runs, it installs Downstream Keyer from the bundle if it is missing, and replaces it if it came from Flathub or from an older bundle. If the bundle is removed from the `vendor` folder, the next run goes back to the Flathub version.

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
# Adding a Scene Collection
To add a scene collection you do not currently have, close OBS and run one of the following in a normal terminal, without sudo. It only adds the scene collection: nothing is installed or updated, and OBS still opens with the same collection as before. Afterwards, pick the new one from the Scene Collection menu in OBS.

A scene collection that is already on the computer is left alone, so changes made in OBS are kept. Add `--force` to the end of the command to replace it; the old one is saved as a .bak file.
* **Single Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    ./tools/add-obs-scene-collection.sh --config=single-camera
    ```
* **Dual Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    ./tools/add-obs-scene-collection.sh --config=dual-camera
    ```
* **Stake Conference Camera Configuration**
    ```terminal
    cd ~/church-obs-setup
    ./tools/add-obs-scene-collection.sh --config=stake-conference
    ```
* **Primary Program Config - Installing from this Fork and Branch**

    The Primary Program scene collection is only on the `primary-program-config-files` branch of the harmanmj fork. These commands clone that branch into a separate `~/church-obs-setup-temp` folder, so the main `~/church-obs-setup` folder is left as it is. Close OBS, then run them in a normal terminal, without `sudo`:
    ```terminal
    cd ~
    git clone -b primary-program-config-files https://github.com/harmanmj/church-obs-setup.git ~/church-obs-setup-temp
    cd ~/church-obs-setup-temp
    ./tools/add-obs-scene-collection.sh --config=primary-program
    ```
    If `~/church-obs-setup-temp` is already there from an earlier time, run `cd ~/church-obs-setup-temp` and `git pull` instead of the `git clone` line. The scene collection is copied into OBS, so the temp folder can be deleted afterwards with `rm -rf ~/church-obs-setup-temp`.

    Pick Primary Program from the Scene Collection menu in OBS. The two FreeShow lower third sources start blank, so select the NDI output from the computer running FreeShow for each one. If the script warns that a plugin is missing, run `cd ~/church-obs-setup` and then `sudo ./setup-obs-flatpak.sh --no-config` once. This installs the plugins without changing any scene collection.
If the command or the scene collection is not found, this computer has an older copy of the setup. Run the update above once, then this will work.

# Resetting OBS Video Settings
The video settings (1920x1080 canvas and output, 30 fps, recording quality "Same as stream") are only set the first time the script sets up OBS, so changes made in OBS are kept. To set them again if settings were changed for some reason, close OBS and run the following in a normal terminal, without sudo. It changes only these video settings, in every OBS profile, and does not run the rest of the setup.
* **Reset OBS Video Settings**
    ```terminal
    cd ~/church-obs-setup
    python3 tools/set-obs-video.py
    ```
