# vi-faithful Neovim setup

Portable Neovim (+ Neovide GUI) config for a longtime vi user.

## Install on a new machine
```sh
git clone <this-repo-url> nvim-setup
cd nvim-setup
./install.sh
```
Detects Arch / Debian / RHEL derivatives, installs Neovim (and Neovide where
possible), and copies `init.vim` to `~/.config/nvim/` (backing up any existing
config). Run as your normal user — it uses `sudo` only for package installs.

## Files
- `install.sh` — detect distro, install packages, deploy config
- `init.vim`   — the Neovim configuration
