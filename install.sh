#!/usr/bin/env bash
#
# install.sh — set up a vi-faithful Neovim (+ Neovide GUI) on a new machine.
#
# Detects the distro family (Arch / Debian / RHEL derivatives), installs
# Neovim if it is not already present, best-effort installs the Neovide GUI,
# and copies init.vim (shipped alongside this script) into ~/.config/nvim/.
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

# --- install Neovide GUI (best effort; config works without it) ---------------
install_neovide() {
  if have neovide; then
    log "Neovide already installed"
    return
  fi
  log "Installing Neovide (GUI)..."
  if [ "$FAMILY" = "arch" ]; then
    if $SUDO pacman -S --needed --noconfirm neovide; then
      log "Neovide installed"
      return
    fi
  fi
  # Debian/RHEL: not in default repos — try Flatpak, else advise manual install.
  if have flatpak; then
    if $SUDO flatpak install -y flathub dev.neovide.neovide; then
      log "Neovide installed via Flatpak (run: flatpak run dev.neovide.neovide)"
      return
    fi
  fi
  warn "Neovide not auto-installed on this distro. Terminal 'nvim' is fully"
  warn "configured. For the GUI, grab a release from https://neovide.dev or"
  warn "install Flatpak then re-run this script."
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

# --- run ---------------------------------------------------------------------
install_neovim
install_neovide
install_config

log "Done. Launch 'nvim' in a terminal, or 'neovide' for the GUI."
