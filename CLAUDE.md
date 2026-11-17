# Handoff: Update OBS button

Handoff notes for the `obs-update-button` branch. Last updated 2026-11-16. Delete this file, or rewrite it as general project notes, before merging to `main`.

## Goal

Volunteers run the stream in three buildings. They do not have the sudo password and should not need a terminal. A one-click **Update OBS** button in the dock gets the latest scene collections. It does **not** update software or plugins (that stays `sudo ./setup-obs-flatpak.sh --install`). Getting the latest repository must not need sudo either. Linux only; no Windows version is planned for now.

## Current state

- **Branch:** `obs-update-button`, rebuilt on 2026-11-16 on top of `november-scene-collection-updates` (`053dfa1`, the future PR #23). The PR goes in with or after that one.
- **Old history:** the first design (a root systemd service + polkit) and its notes are kept on `backup/obs-update-button-pre-rebase`. Delete that branch once this one has been tested.
- **Pushed:** no. Push it before testing on Ubuntu, because the button downloads from GitHub.
- **Tested:** only `bash -n` syntax checks. Nothing has run on an Ubuntu machine yet.
- **Mockup:** https://claude.ai/artifact/18mPd3bf1qmHZuAjkCjsGL (private until shared).

## Design

Nothing the button runs needs root, because everything it changes is in the volunteer's home folder.

| Piece | Runs as | What it does |
|---|---|---|
| `tools/obs-update-button.sh` | the user | The zenity dialogs: an "OBS is open" warning, a progress window, then the result (done, or the error and its details). There are no choices to make. A lock makes a double click do nothing. The log is in `~/.cache/church-obs-update.log`. |
| `update-obs-config.sh` | the user | Fast-forwards its own clone to its upstream (`git fetch` + `merge --ff-only @{u}`), re-runs the new copy, then runs the base branch's `tools/update-obs-collections.py` with no terminal, so it doesn't change which collection OBS opens on. If the active collection is one of the repo's, it runs `set-obs-collection.py` on it again, which picks up a renamed collection. |
| `~/church-obs-setup` | owned by the user | The clone the README makes. Setup clones it when missing, and `chown`s it to the user, because the README used to say `sudo git clone`. So the button and `git pull` work without sudo. Setup sets an upstream if the clone has none. It switches the clone's repo or branch only when `UPDATE_REPO`/`UPDATE_BRANCH` are given **and** setup is run from another copy. |
| `setup-obs-flatpak.sh` | root (admin, sudo) | Adds `git` and `zenity` to the apt packages, prepares `~/church-obs-setup`, writes `/usr/share/applications/church-obs-update.desktop`, and with `--pin-dock` pins it next to OBS. The rest is as on the base branch. |

**Download source when setup clones:** `UPDATE_REPO`/`UPDATE_BRANCH`, else what `~/church-obs-setup` already follows, else what the copy setup runs from follows, else `harmanmj/church-obs-setup` `main`.

## Decisions made

- The button only updates scene collections (through `update-obs-collections.py`, which also keeps device picks, builds the notch VSTs and installs the dock layout). It never updates software. It does not touch the audio, WebSocket or video settings.
- One click, no options.
- The button uses `~/church-obs-setup`, not a separate hidden copy, so there is one copy to keep up to date.
- Updates pull from **harmanmj** for testing. The final source will be **Sam's repo** (`smitchell7/church-obs-setup`); see the TODO in `setup-obs-flatpak.sh` near `UPDATE_REPO`.

## Outstanding tasks

1. Push: `git push -u origin obs-update-button` (a force push is needed if it was ever pushed before; it wasn't as of 2026-11-16).
2. **Test on an Ubuntu 24.04 computer:** `git clone` harmanmj (or reuse a root-owned clone to test the `chown`), check out `obs-update-button`, run `sudo ./setup-obs-flatpak.sh --pin-dock`. Then check:
   - The launcher is in the dock and starts with one click, and a double click runs it only once.
   - `git pull` in `~/church-obs-setup` works without sudo.
   - The collections update, the active collection stays active, and device picks are kept.
   - The warning when OBS is open, and the error and details dialogs with no network.
3. **Things to verify:**
   - What OBS 31/32 stores in `user.ini` `SceneCollectionFile`, with or without `.json`. The active-collection check accepts both.
   - zenity 4: `--progress --pulsate --auto-close` with `#` lines.
   - The autoinstall (`/opt/church-obs-setup`, root-owned) also gets a working `~/church-obs-setup` for the `broadcast` user.
4. **Before merging:**
   - Switch the default `UPDATE_REPO` to smitchell7.
   - Change the README's `git clone` URLs if needed.
   - Delete this `CLAUDE.md` (or rewrite it as general project notes).
   - Open a PR to `main` after `november-scene-collection-updates`.
5. **Optional:** an automatic weekly run with a systemd user timer; pulling only tagged releases instead of a branch.

## Other branches (from memory)

- `primary-program-config-files` is temporary.
