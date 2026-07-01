#!/usr/bin/env bash
#
# install.sh — set up a vi-faithful Neovim (+ goneovim GUI) on a new machine.
#
# Detects the distro family (Arch / Debian / RHEL derivatives), installs
# Neovim if it is not already present, best-effort installs the goneovim GUI
# (native drag-and-drop file open), and copies init.vim (shipped alongside
# this script) into ~/.config/nvim/.
#
# Usage:  git clone <repo> && cd <repo> && ./install.sh
# Run as your normal user; the script calls sudo only for package installs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/init.vim"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
CONFIG_DST="$CONFIG_DIR/init.vim"

# --- pretty output -----------------------------------------------------------
c_grn=$'\033[1;32m'; c_ylw=$'\033[1;33m'; c_red=$'\033[1;31m'; c_rst=$'\033[0m'
log()  { printf '%s==>%s %s\n' "$c_grn" "$c_rst" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$c_ylw" "$c_rst" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "$c_red" "$c_rst" "$*" >&2; exit 1; }

# --- helpers -----------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# --- CLI flags ---------------------------------------------------------------
# VI_DEFAULT: point 'vi' at Neovim:  ask (default) | yes | no
# GUI:        install the goneovim GUI:  auto (default; skip if headless) | yes | no
VI_DEFAULT=ask
GUI=auto
usage() {
  cat <<USAGE
Usage: ./install.sh [--vi|--no-vi] [--gui|--no-gui]
  --vi       make 'vi' launch Neovim without prompting
  --no-vi    leave 'vi' untouched without prompting
  --gui      force-install the goneovim GUI even if no display is detected
  --no-gui   skip the GUI (Neovim + config only) -- good for headless servers
  (default)  prompt about 'vi'; auto-detect GUI (skipped on headless machines)
USAGE
}
for arg in "$@"; do
  case "$arg" in
    --vi)      VI_DEFAULT=yes ;;
    --no-vi)   VI_DEFAULT=no ;;
    --gui)     GUI=yes ;;
    --no-gui)  GUI=no ;;
    -h|--help) usage; exit 0 ;;
    *) warn "ignoring unknown argument: $arg" ;;
  esac
done

# --- is there a graphical environment worth installing a GUI for? -------------
# Returns 0 (yes) / 1 (no). Honors --gui/--no-gui; otherwise auto-detects.
has_gui() {
  case "$GUI" in
    yes) return 0 ;;
    no)  return 1 ;;
  esac
  # A live display in this session (X11 or Wayland) is a clear yes.
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    return 0
  fi
  # No display in this shell (e.g. plain SSH): fall back to whether the system
  # is configured to boot into a graphical session.
  if have systemctl && [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
    return 0
  fi
  return 1
}

[ -f "$CONFIG_SRC" ] || die "init.vim not found next to this script ($CONFIG_SRC)"

# --- detect distro family ----------------------------------------------------
[ -r /etc/os-release ] || die "/etc/os-release not found; cannot identify distro"
# shellcheck disable=SC1091
. /etc/os-release
haystack=" ${ID:-} ${ID_LIKE:-} "
case "$haystack" in
  *arch*|*manjaro*|*endeavouros*|*cachyos*)                 FAMILY=arch ;;
  *debian*|*ubuntu*|*mint*|*pop*|*raspbian*)                FAMILY=debian ;;
  *rhel*|*fedora*|*centos*|*rocky*|*almalinux*|*ol*)        FAMILY=rhel ;;
  *) die "unsupported distro: ID='${ID:-?}' ID_LIKE='${ID_LIKE:-?}'" ;;
esac
log "Detected ${PRETTY_NAME:-${ID:-unknown}}  ->  ${FAMILY} family"

# --- install Neovim (only if missing) ----------------------------------------
install_neovim() {
  if have nvim; then
    log "Neovim already installed: $(nvim --version | head -1)"
    return
  fi
  log "Installing Neovim..."
  case "$FAMILY" in
    arch)
      $SUDO pacman -S --needed --noconfirm neovim
      ;;
    debian)
      $SUDO apt-get update
      $SUDO apt-get install -y neovim
      ;;
    rhel)
      local PM; PM=$(have dnf && echo dnf || echo yum)
      if ! $SUDO "$PM" install -y neovim; then
        warn "Neovim not in enabled repos. On RHEL/CentOS enable EPEL first:"
        warn "  $SUDO $PM install -y epel-release   (then re-run this script)"
        die "Neovim install failed"
      fi
      ;;
  esac
  have nvim || die "Neovim installation did not produce an 'nvim' binary"
  log "Neovim installed: $(nvim --version | head -1)"
}

# --- install goneovim GUI (best effort; config works without it) --------------
# goneovim is chosen for its native drag-and-drop "open file" support.
install_goneovim() {
  if ! has_gui; then
    log "No graphical environment detected -> skipping GUI (headless). Use --gui to force."
    return
  fi
  if have goneovim; then
    log "goneovim already installed"
    return
  fi
  log "Installing goneovim (GUI)..."
  case "$FAMILY" in
    arch)
      # AUR package 'goneovim-bin' (prebuilt). Needs an AUR helper; do NOT run
      # AUR helpers under sudo -- they invoke sudo themselves when needed.
      local helper=""
      for h in paru yay pikaur; do
        if have "$h"; then helper="$h"; break; fi
      done
      if [ -n "$helper" ]; then
        "$helper" -S --needed --noconfirm goneovim-bin && { log "goneovim installed via $helper"; return; }
      else
        warn "No AUR helper (paru/yay) found. Install one, then: paru -S goneovim-bin"
      fi
      ;;
    debian|rhel)
      install_goneovim_release && return
      ;;
  esac
  warn "goneovim not auto-installed. Terminal 'nvim' is fully configured; grab a"
  warn "release from https://github.com/akiyosi/goneovim/releases for the GUI."
}

# Fetch the latest goneovim Linux release into ~/.local (best effort).
install_goneovim_release() {
  have curl || { warn "curl required to fetch goneovim release"; return 1; }
  have tar  || { warn "tar required to unpack goneovim release"; return 1; }
  local api url tmp dest bin
  api="https://api.github.com/repos/akiyosi/goneovim/releases/latest"
  url="$(curl -fsSL "$api" 2>/dev/null | grep -oE 'https://[^"]*[Ll]inux[^"]*\.tar\.bz2' | head -1)"
  [ -n "$url" ] || { warn "could not locate a goneovim Linux release asset"; return 1; }
  tmp="$(mktemp -d)"
  log "Downloading $(basename "$url")..."
  curl -fsSL "$url" -o "$tmp/g.tar.bz2" || { warn "download failed"; rm -rf "$tmp"; return 1; }
  tar xjf "$tmp/g.tar.bz2" -C "$tmp" || { warn "extract failed"; rm -rf "$tmp"; return 1; }
  bin="$(find "$tmp" -maxdepth 3 -type f -name goneovim | head -1)"
  [ -n "$bin" ] || { warn "goneovim binary not found in archive"; rm -rf "$tmp"; return 1; }
  dest="$HOME/.local/share/goneovim"
  rm -rf "$dest"; mkdir -p "$dest" "$HOME/.local/bin"
  cp -r "$(dirname "$bin")/." "$dest/"
  ln -sf "$dest/goneovim" "$HOME/.local/bin/goneovim"
  rm -rf "$tmp"
  log "Installed goneovim -> ~/.local/bin/goneovim (ensure ~/.local/bin is on PATH)"
}

# --- copy config (with backup) -----------------------------------------------
install_config() {
  mkdir -p "$CONFIG_DIR"
  if [ -f "$CONFIG_DST" ] && ! cmp -s "$CONFIG_SRC" "$CONFIG_DST"; then
    local ts backup
    ts=$(date +%Y%m%d-%H%M%S)
    backup="$CONFIG_DST.bak.$ts"
    cp "$CONFIG_DST" "$backup"
    log "Backed up existing config -> $backup"
  fi
  cp "$CONFIG_SRC" "$CONFIG_DST"
  log "Installed config -> $CONFIG_DST"
}

# --- make 'vi' launch Neovim (opt-in; prompts unless --vi/--no-vi given) ------
setup_vi_default() {
  case "$VI_DEFAULT" in
    no)  log "Leaving 'vi' unchanged (--no-vi)"; return ;;
    yes) : ;;
    ask)
      if [ ! -t 0 ]; then
        warn "Non-interactive shell; not touching 'vi'. Re-run with --vi to enable."
        return
      fi
      printf '%s==>%s Make '\''vi'\'' launch Neovim system-wide (symlink, needs sudo)? [y/N] ' "$c_grn" "$c_rst"
      local reply=""
      read -r reply </dev/tty || true
      case "$reply" in
        [yY]|[yY][eE][sS]) : ;;
        *) log "Leaving 'vi' unchanged"; return ;;
      esac
      ;;
  esac

  local nvim_bin; nvim_bin="$(command -v nvim)"
  case "$FAMILY" in
    arch)
      # /usr/local/bin wins on PATH for both the user and sudo's secure_path.
      $SUDO ln -sf "$nvim_bin" /usr/local/bin/vi
      log "Linked /usr/local/bin/vi -> $nvim_bin"
      # Also claim /usr/bin/vi (what vipw/visudo hardcode) IF no package owns it.
      if [ -e /usr/bin/vi ] && pacman -Qo /usr/bin/vi >/dev/null 2>&1; then
        warn "/usr/bin/vi is owned by a package; left as-is (remove the 'vi' pkg to fully switch)."
      else
        $SUDO ln -sf "$nvim_bin" /usr/bin/vi
        log "Linked /usr/bin/vi -> $nvim_bin"
      fi
      ;;
    debian)
      # Use the alternatives system so dpkg stays happy.
      if have update-alternatives; then
        $SUDO update-alternatives --install /usr/bin/vi vi "$nvim_bin" 60
        $SUDO update-alternatives --set vi "$nvim_bin"
        log "Registered 'vi' alternative -> $nvim_bin"
      else
        $SUDO ln -sf "$nvim_bin" /usr/local/bin/vi
        log "Linked /usr/local/bin/vi -> $nvim_bin"
      fi
      ;;
    rhel)
      # /usr/bin/vi is owned by vim-minimal; don't overwrite an rpm file.
      $SUDO ln -sf "$nvim_bin" /usr/local/bin/vi
      log "Linked /usr/local/bin/vi -> $nvim_bin"
      warn "On RHEL, tools hardcoding /usr/bin/vi will still use the packaged vi."
      ;;
  esac
  log "Tip: a shell alias (e.g. fish ~/.config/fish/functions/vi.fish) can still shadow this."
}

# --- run ---------------------------------------------------------------------
install_neovim
install_goneovim
install_config
setup_vi_default

log "Done. Launch 'nvim' in a terminal, or 'goneovim' for the GUI."
