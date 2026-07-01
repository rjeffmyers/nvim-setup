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

### Making `vi` launch Neovim (optional)
By default the installer **prompts** whether to point `vi` at Neovim
system-wide (Arch: symlink; Debian: `update-alternatives`; RHEL:
`/usr/local/bin` symlink). Skip the prompt with a flag:
```sh
./install.sh --vi      # do it without asking
./install.sh --no-vi   # never touch 'vi'
```
Note: a shell alias (e.g. `~/.config/fish/functions/vi.fish`) can still shadow
this for that user — remove it if `vi` doesn't pick up Neovim.

## Files
- `install.sh` — detect distro, install packages, deploy config
- `init.vim`   — the Neovim configuration
