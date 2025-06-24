# Simple Symlink Manager

This is a Bash script with a graphical interface (using Zenity) to manage symbolic links between directories using named profiles. It allows you to create, edit, and delete profiles, and easily create or remove symlinks for files and folders between source and target directories.

## Features
- **Profile Management:** Save source/target directory pairs as profiles for quick access.
- **Symlink Creation:** Select files/folders from a source directory to symlink into a target directory.
- **Symlink Deletion:** Remove all or selected symlinks from a target directory.
- **Graphical Interface:** All actions are performed via Zenity dialogs.

## Requirements
- Bash
- [Zenity](https://help.gnome.org/users/zenity/stable/) (for GUI dialogs)
- [jq](https://stedolan.github.io/jq/) (for JSON parsing)

Install dependencies on Ubuntu/Debian:
```sh
sudo apt install zenity jq
```

Install dependencies on Fedora:
```sh
sudo dnf install zenity jq
```

Install dependencies on Arch Linux/Manjaro:
```sh
sudo pacman -S zenity jq
```

Install dependencies on openSUSE:
```sh
sudo zypper install zenity jq
```

## Usage
1. **Make the script executable:**
   ```sh
   chmod +x symlink.sh
   ```
2. **Run the script:**
   ```sh
   ./symlink.sh
   ```
3. **Follow the GUI prompts:**
   - Create a new profile (source/target directories)
   - Select a profile to create symlinks
   - Edit or delete profiles
   - Delete symlinks from a target directory

All profile data is stored in `~/.symlink_manager/profiles.json`.

## Notes
- Existing files/symlinks in the target directory with the same name will be overwritten when creating symlinks.
- The script is intended for local use with directories you have permission to modify.

## Troubleshooting
- If you see errors about missing `zenity` or `jq`, install them as shown above.
- If the GUI does not appear, ensure you are running in a graphical desktop environment.

---
**Author:** [Ahmed Saad]
**Date:** June 24, 2025
