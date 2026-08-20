#!/usr/bin/env bash
# nix/setup-wsl.sh - guided bootstrap for a fresh WSL machine.
#
# Interactive installer that takes a bare WSL machine (nix only - no git, no
# editors, no checkout) to a fully configured dotfiles setup:
#
#   1. detects the environment (WSL, distro, nix, git)
#   2. asks where to get the repo from (home LAN Gitea / public GitHub mirror /
#      an existing local checkout) and walks through every per-machine env
#      value with sensible WSL defaults (Enter accepts the [default])
#   3. fetches the repo to ~/.dotfiles, writes ~/.config/dotfiles/env, then
#      builds + activates the right host: the full NixOS-WSL system
#      (nixosConfigurations.wsl, sudo ./result/bin/switch-to-configuration
#      switch) on NixOS, or the portable dev-only home-manager profile
#      (homeConfigurations.server, ./result/activate) on any other distro.
#
# Only nix is required: nix fetches the repo itself (nix-prefetch-url --unpack
# for archives, libgit2 for git). git is only used when present and chosen for
# a clone. Flakes are enabled per-invocation via NIX_CONFIG - on NixOS the
# generated /etc/nix/nix.conf is read-only, so never instruct editing it.
#
# The build evaluates the flake from the remote URL without a checkout, with
# the per-machine env file fed in as an input override (pure evaluation stays
# intact; the override is not written to flake.lock):
#   nix build '<url>?dir=nix#<attr>' \
#     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
#
# Usage:
#   setup-wsl.sh [--dry-run] [--help]
#
#   --dry-run  run detection and prompts, then print every command that would
#              run - nothing is fetched, written, built or activated.
#
# Non-interactive / testing: pipe answers on stdin (empty line accepts the
# default, EOF accepts defaults for the rest) and set SETUP_WSL_YES=1 to
# auto-confirm, e.g.:
#   printf '1\n\n\n\n...\n' | SETUP_WSL_YES=1 ./setup-wsl.sh
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: setup-wsl.sh [--dry-run] [--help]

Guided bootstrap of this dotfiles repo on a fresh WSL machine.

  --dry-run  run detection and prompts, then print every command that would
             run - change nothing
  --help     show this help

Environment (all optional):
  SETUP_WSL_YES=1      auto-confirm the final yes/no (testing/scripts)
  SETUP_WSL_ENV_FILE   where to write the env file
                       (default ~/.config/dotfiles/env)
  SETUP_WSL_OS_ID      pretend /etc/os-release ID is this value, e.g. nixos
                       (test hook - normally read from /etc/os-release)
EOF
  exit 1
}

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run | --check) DRY_RUN=1 ;;
    --help | -h) usage ;;
    -*)
      echo "error: unknown option: $arg" >&2
      usage
      ;;
  esac
done

# Repo root is the parent of this script's directory (the script lives in nix/).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Per-machine env file location (override for testing).
ENV_FILE="${SETUP_WSL_ENV_FILE:-$HOME/.config/dotfiles/env}"

log()  { printf '\n== %s ==\n' "$*"; }
info() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# ask <prompt> <default>: prints the prompt (with "[default]: " when a
# default exists) on stderr and echoes the answer on stdout. Empty input takes
# the default; with no default, empty input echoes empty (the caller decides
# whether that means skip or re-prompt). Prompts go to stderr so the answer can
# be captured with $(ask ...).
ask() {
  local prompt="$1" default="$2" answer
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r answer || answer=""
  printf '%s\n' "${answer:-$default}"
}

# ask_skip <prompt> <default>: like ask, but 'skip' or '-' echoes nothing so
# the caller can omit a machine-specific key entirely. With an empty default,
# pressing Enter also omits it (the caller warns) - a fresh machine never
# silently gets a made-up value.
ask_skip() {
  local prompt="$1" default="$2" answer
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r answer || answer=""
  case "$answer" in
    skip | SKIP | -) printf '\n' ;;
    *) printf '%s\n' "${answer:-$default}" ;;
  esac
}

confirm() {
  local answer
  if [ "${SETUP_WSL_YES:-0}" = 1 ]; then
    printf 'proceeding (SETUP_WSL_YES=1)\n'
    return 0
  fi
  printf '%s [y/N]: ' "$1" >&2
  IFS= read -r answer || answer="n"
  case "$answer" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# --- environment detection ----------------------------------------------------

log "Environment"

IS_WSL=0
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || \
   [ -n "${WSL_DISTRO_NAME:-}" ] || \
   grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
  IS_WSL=1
fi

if [ "$IS_WSL" -eq 1 ]; then
  info "WSL detected (distro env: ${WSL_DISTRO_NAME:-unknown})"
else
  warn "not running under WSL - this script targets WSL but still works on any"
  warn "Linux with nix; the distro detection below picks the build target."
fi

if [ -n "${SETUP_WSL_OS_ID:-}" ]; then
  OS_ID="$SETUP_WSL_OS_ID"
else
  OS_ID=""
  if [ -f /etc/os-release ]; then
    OS_ID="$(sed -n 's/^ID=//p' /etc/os-release | head -n 1)"
  fi
fi
IS_NIXOS=0
if [ "$OS_ID" = nixos ]; then
  IS_NIXOS=1
  info "distro: NixOS-WSL (full system build: nixosConfigurations.wsl)"
else
  info "distro: ${OS_ID:-unknown} (non-NixOS: portable home-manager profile, homeConfigurations.server)"
fi

if ! command -v nix >/dev/null 2>&1; then
  if [ "$IS_NIXOS" -eq 1 ]; then
    die "nix is not on PATH, but NixOS-WSL ships with it preinstalled - check your PATH (/nix/var/nix/profiles/default/bin/nix)"
  fi
  cat >&2 <<'EOF'
error: nix is not installed. Install it first, e.g.:
  sh <(curl -L https://nixos.org/nix/install) --daemon
or the Determinate Nix installer: https://install.determinate.systems
then re-run this script.
EOF
  exit 1
fi
info "nix: $(nix --version)"

HAS_GIT=0
if command -v git >/dev/null 2>&1; then
  HAS_GIT=1
  info "git: $(git --version)"
else
  info "git: not found (fine - nix fetches the repo itself; git is only used for a clone if you pick that source)"
fi

if [ "$(id -u)" -eq 0 ]; then
  warn "running as root - DOTFILES_USERNAME should be your regular WSL user, not root"
fi

# --- repo source ----------------------------------------------------------------

# Nothing personal is hardcoded here: this repo is public, and each user's
# Gitea host/owner differs, so option 1 prompts for the repo URL. GITEA_REPO_URL
# and LAN_URL are filled in below when option 1 is chosen.
GITEA_REPO_URL=""
LAN_URL=""
GH_URL="https://github.com/babbarc/dotfiles.git"
GH_TARBALL="https://github.com/babbarc/dotfiles/archive/refs/heads/master.tar.gz"

log "Repo source"
cat <<'EOF'
Where should I get the dotfiles repo from?
  1) Your own Gitea server (e.g. on your home LAN) - I'll ask for its URL
  2) Public GitHub mirror - github.com/babbarc/dotfiles
  3) An existing local checkout - I'll ask for its path
If you are not sure, pick 2 - the GitHub mirror needs no setup.
EOF
SOURCE="$(ask 'choice' 1)"
while :; do
  case "$SOURCE" in
    1 | 2 | 3) break ;;
    *)
      warn "'$SOURCE' is not a valid choice - enter 1, 2 or 3"
      SOURCE="$(ask 'choice' 1)"
      ;;
  esac
 done

if [ "$SOURCE" = 1 ]; then
  while :; do
    printf '%s: ' 'Gitea repo URL (e.g. http://gitea.example.com:3222/user/dotfiles, no trailing slash)' >&2
    if ! IFS= read -r gitea_answer; then
      die "no Gitea URL provided (stdin ended) - re-run and type it, or pick option 2 for the GitHub mirror"
    fi
    GITEA_REPO_URL="${gitea_answer%/}"
    if [ -n "$GITEA_REPO_URL" ]; then
      break
    fi
    warn "the Gitea repo URL must not be empty - type it, or pick option 2 for the GitHub mirror"
  done
  LAN_URL="$GITEA_REPO_URL/archive/master.tar.gz"
  info "Gitea source: $LAN_URL"
fi

# Natural default for source 3: the checkout this script is running from (e.g.
# ~/.dotfiles after a bootstrap, or any worktree), else ~/.dotfiles.
if [ -f "$REPO/nix/flake.nix" ]; then
  LOCAL_REPO_DEFAULT="$REPO"
else
  LOCAL_REPO_DEFAULT="$HOME/.dotfiles"
fi
LOCAL_REPO="$LOCAL_REPO_DEFAULT"
if [ "$SOURCE" = 3 ]; then
  while :; do
    LOCAL_REPO="$(ask 'path to your existing dotfiles checkout' "$LOCAL_REPO")"
    LOCAL_REPO="${LOCAL_REPO/#\~/$HOME}"
    if [ -f "$LOCAL_REPO/nix/flake.nix" ]; then
      break
    fi
    warn "no nix/flake.nix found at $LOCAL_REPO - enter the path to a dotfiles checkout"
  done
  info "using existing checkout at $LOCAL_REPO"
fi

# --- per-machine env values ------------------------------------------------------

log "Per-machine values"

# An existing env file's values become the prompt defaults (later lines win),
# so a re-run keeps the machine's setup. An empty line in the prompts keeps
# the [default]; type 'skip' to omit a machine-specific key.
declare -A DEF=()
ENV_EXISTED=0
if [ -f "$ENV_FILE" ]; then
  ENV_EXISTED=1
  info "found existing env file at $ENV_FILE - its values are the defaults below (Enter keeps them)"
  while IFS= read -r line; do
    line="${line%$'\r'}"
    case "$line" in
      '' | '#'*) continue ;;
    esac
    key="${line%%=*}"
    DEF["$key"]="${line#*=}"
  done < "$ENV_FILE"
fi

def() { printf '%s' "${DEF[$1]:-${2:-}}"; }

info "Prompts with a [default] accept it with Enter. Optional machine-specific"
info "values (server, joy-console, stereo, wezterm) are omitted by Enter or"
info "'skip' - each omission prints a warning so nothing breaks silently."

CUR_USER="${USER:-$(id -un)}"
DOTFILES_USERNAME="$(ask 'Username of your user on this WSL machine' "$(def DOTFILES_USERNAME "$CUR_USER")")"
while [ -z "$DOTFILES_USERNAME" ]; do
  warn "the username must not be empty"
  DOTFILES_USERNAME="$(ask 'Username of your user on this WSL machine' "$CUR_USER")"
done
case "$DOTFILES_USERNAME" in
  *' '*) die "username contains spaces: '$DOTFILES_USERNAME'" ;;
esac

DOTFILES_HOST_ROLE="$(ask 'Host role for this machine (laptop/server/wsl)' "$(def DOTFILES_HOST_ROLE wsl)")"
case "$DOTFILES_HOST_ROLE" in
  laptop | server | wsl) ;;
  *) warn "unusual host role '$DOTFILES_HOST_ROLE' - the flake only defines laptop, server and wsl" ;;
esac

DOTFILES_SERVER_HOST="$(ask_skip 'Home server hostname or ssh alias' "$(def DOTFILES_SERVER_HOST "")")"
if [ -z "$DOTFILES_SERVER_HOST" ]; then
  warn "skipped DOTFILES_SERVER_HOST - wezterm's ssh domain and the fish joy-console won't know your server"
fi
DOTFILES_SERVER_USER="$(ask_skip 'Username to ssh into the server as (same as yours by default)' "$(def DOTFILES_SERVER_USER "$DOTFILES_USERNAME")")"
if [ -z "$DOTFILES_SERVER_USER" ]; then
  warn "skipped DOTFILES_SERVER_USER - ssh-to-server integrations won't know which user to use"
fi

log "joy-console (a container on the server - machine-specific, Enter or 'skip' omits)"
JOY_CONSOLE_CONTAINER_USER="$(ask_skip 'Container user (sudo -u target)' "$(def JOY_CONSOLE_CONTAINER_USER "")")"
JOY_CONSOLE_CONTAINER="$(ask_skip 'Container name (podman exec target)' "$(def JOY_CONSOLE_CONTAINER "")")"
JOY_CONSOLE_CONTAINER_HOME="$(ask_skip 'Container user home directory' "$(def JOY_CONSOLE_CONTAINER_HOME "")")"
[ -n "$JOY_CONSOLE_CONTAINER_USER" ] || warn "skipped JOY_CONSOLE_CONTAINER_USER - the joy-console function won't work"
[ -n "$JOY_CONSOLE_CONTAINER" ] || warn "skipped JOY_CONSOLE_CONTAINER - the joy-console function won't work"
[ -n "$JOY_CONSOLE_CONTAINER_HOME" ] || warn "skipped JOY_CONSOLE_CONTAINER_HOME"

log "stereo-transcode (a LAN service - machine-specific, Enter or 'skip' omits)"
STEREO_TRANSCODE_ENDPOINT="$(ask_skip 'HTTP endpoint' "$(def STEREO_TRANSCODE_ENDPOINT "")")"
[ -n "$STEREO_TRANSCODE_ENDPOINT" ] || warn "skipped STEREO_TRANSCODE_ENDPOINT - the stereo-transcode CLI won't work"

log "wezterm (Windows-side config, machine-specific - Enter or 'skip' omits any)"
WEZTERM_SSH_WSL_USER="$(ask_skip 'ssh:wsl domain user (Windows -> this WSL distro)' "$(def WEZTERM_SSH_WSL_USER wsl-ssh-user)")"
WEZTERM_WSL_DISTRO="$(ask_skip 'WSL distro name (old Ubuntu setup)' "$(def WEZTERM_WSL_DISTRO Ubuntu)")"
WEZTERM_WSL_FISH_USER="$(ask_skip 'wsl:ubuntu-fish domain user' "$(def WEZTERM_WSL_FISH_USER wsl-fish-user)")"
WEZTERM_WSL_FISH_CWD="$(ask_skip 'wsl:ubuntu-fish domain cwd' "$(def WEZTERM_WSL_FISH_CWD /home/wsl-fish-user)")"
WEZTERM_WSL_BASH_USER="$(ask_skip 'wsl:ubuntu-bash domain user' "$(def WEZTERM_WSL_BASH_USER wsl-bash-user)")"
WEZTERM_WSL_BASH_CWD="$(ask_skip 'wsl:ubuntu-bash domain cwd' "$(def WEZTERM_WSL_BASH_CWD /home/wsl-bash-user)")"
WEZTERM_WSL_SYSTEM_USER="$(ask_skip 'NixOS-WSL system user (matches your username)' "$(def WEZTERM_WSL_SYSTEM_USER "$DOTFILES_USERNAME")")"
WEZTERM_GIT_BASH_PATH="$(ask_skip 'Git Bash bash.exe path on Windows' "$(def WEZTERM_GIT_BASH_PATH 'C:\Users\your-user\scoop\apps\git\current\bin\bash.exe')")"
# One warning per skipped key - these are Windows-side values, so omitting
# them only affects wezterm's WSL/ssh domains on the Windows machine.
[ -n "$WEZTERM_SSH_WSL_USER" ] || warn "skipped WEZTERM_SSH_WSL_USER - the ssh:wsl wezterm domain won't be configured"
[ -n "$WEZTERM_WSL_DISTRO" ] || warn "skipped WEZTERM_WSL_DISTRO - the wsl:ubuntu-fish domain won't know the distro"
[ -n "$WEZTERM_WSL_FISH_USER" ] || warn "skipped WEZTERM_WSL_FISH_USER - the wsl:ubuntu-fish domain won't be configured"
[ -n "$WEZTERM_WSL_FISH_CWD" ] || warn "skipped WEZTERM_WSL_FISH_CWD"
[ -n "$WEZTERM_WSL_BASH_USER" ] || warn "skipped WEZTERM_WSL_BASH_USER - the wsl:ubuntu-bash domain won't be configured"
[ -n "$WEZTERM_WSL_BASH_CWD" ] || warn "skipped WEZTERM_WSL_BASH_CWD"
[ -n "$WEZTERM_WSL_SYSTEM_USER" ] || warn "skipped WEZTERM_WSL_SYSTEM_USER - the NixOS-WSL wezterm domain won't be configured"
[ -n "$WEZTERM_GIT_BASH_PATH" ] || warn "skipped WEZTERM_GIT_BASH_PATH - the wezterm Git Bash launch-menu entry won't be configured"

# --- assemble the env file ----------------------------------------------------------

# env_line <key> <value>: echoes "key=value", or nothing when the value is
# empty (skipped keys stay out of the file entirely).
env_line() {
  if [ -n "$2" ]; then
    printf '%s=%s\n' "$1" "$2"
  fi
}

ENV_CONTENT="# Generated by nix/setup-wsl.sh on $(date '+%F %T') - re-run the script to regenerate.
# Per-machine values for this dotfiles repo. See env.example in the repo for
# documentation of every key. Plaintext and gitignored - keep secrets OUT of
# this file; credentials stay in the OS secret store / pass.

# nix
$(env_line DOTFILES_USERNAME "$DOTFILES_USERNAME")
$(env_line DOTFILES_HOST_ROLE "$DOTFILES_HOST_ROLE")
$(env_line DOTFILES_SERVER_HOST "$DOTFILES_SERVER_HOST")
$(env_line DOTFILES_SERVER_USER "$DOTFILES_SERVER_USER")

# fish joy-console
$(env_line JOY_CONSOLE_CONTAINER_USER "$JOY_CONSOLE_CONTAINER_USER")
$(env_line JOY_CONSOLE_CONTAINER "$JOY_CONSOLE_CONTAINER")
$(env_line JOY_CONSOLE_CONTAINER_HOME "$JOY_CONSOLE_CONTAINER_HOME")

# zsh stereo-transcode
$(env_line STEREO_TRANSCODE_ENDPOINT "$STEREO_TRANSCODE_ENDPOINT")

# wezterm (Windows / WSL)
$(env_line WEZTERM_SSH_WSL_USER "$WEZTERM_SSH_WSL_USER")
$(env_line WEZTERM_WSL_DISTRO "$WEZTERM_WSL_DISTRO")
$(env_line WEZTERM_WSL_FISH_USER "$WEZTERM_WSL_FISH_USER")
$(env_line WEZTERM_WSL_FISH_CWD "$WEZTERM_WSL_FISH_CWD")
$(env_line WEZTERM_WSL_BASH_USER "$WEZTERM_WSL_BASH_USER")
$(env_line WEZTERM_WSL_BASH_CWD "$WEZTERM_WSL_BASH_CWD")
$(env_line WEZTERM_WSL_SYSTEM_USER "$WEZTERM_WSL_SYSTEM_USER")
$(env_line WEZTERM_GIT_BASH_PATH "$WEZTERM_GIT_BASH_PATH")
"

# --- plan -----------------------------------------------------------------------------

# Build target + activation depend on the detected distro.
if [ "$IS_NIXOS" -eq 1 ]; then
  ATTR="nixosConfigurations.wsl.config.system.build.toplevel"
  ACTIVATE=(sudo ./result/bin/switch-to-configuration switch)
  HOST_LABEL="NixOS-WSL system (nixosConfigurations.wsl)"
else
  ATTR="homeConfigurations.server.activationPackage"
  ACTIVATE=(env HOME_MANAGER_BACKUP_EXT=backup ./result/activate)
  HOST_LABEL="portable home-manager profile (homeConfigurations.server)"
fi

UPDATE_REPO="$HOME/.dotfiles" # path used in the update-later commands
case "$SOURCE" in
  1)
    REPO_PLAN="fetch the repo tarball from your Gitea ($LAN_URL) with nix-prefetch-url and unpack it to $HOME/.dotfiles"
    BUILD_FLAKE="$LAN_URL?dir=nix"
    ;;
  2)
    if [ "$HAS_GIT" -eq 1 ]; then
      REPO_PLAN="git clone the public GitHub mirror ($GH_URL) to $HOME/.dotfiles"
      BUILD_FLAKE="$HOME/.dotfiles?dir=nix"
    else
      REPO_PLAN="fetch the repo tarball from the GitHub mirror ($GH_TARBALL) with nix-prefetch-url and unpack it to $HOME/.dotfiles"
      BUILD_FLAKE="$GH_TARBALL?dir=nix"
    fi
    ;;
  3)
    REPO_PLAN="use the existing checkout at $LOCAL_REPO"
    BUILD_FLAKE="$LOCAL_REPO?dir=nix"
    if [ "$LOCAL_REPO" != "$HOME/.dotfiles" ]; then
      UPDATE_REPO="$LOCAL_REPO"
    fi
    ;;
esac

BUILD_CMD=(nix build "$BUILD_FLAKE#$ATTR" --override-input dotfiles-env "path:$ENV_FILE")

# --- dry-run: print the plan, change nothing ----------------------------------------------

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "# dry-run - nothing will be fetched, written, built or activated."
  echo "# plan:"
  echo "#   repo: $REPO_PLAN"
  echo "#   env:  write $ENV_FILE"
  echo "#   host: $HOST_LABEL"
  echo "# commands that WOULD run:"
  echo "  export NIX_CONFIG=\"experimental-features = nix-command flakes\""
  case "$SOURCE" in
    1) echo "  nix-prefetch-url --unpack --print-path \"$LAN_URL\"" ;;
    2)
      if [ "$HAS_GIT" -eq 1 ]; then
        if [ -e "$HOME/.dotfiles" ] && [ -n "$(ls -A "$HOME/.dotfiles" 2>/dev/null)" ]; then
          echo "  # $HOME/.dotfiles already exists - clone skipped, repo reused"
        else
          echo "  git clone \"$GH_URL\" \"$HOME/.dotfiles\""
        fi
      else
        echo "  nix-prefetch-url --unpack --print-path \"$GH_TARBALL\""
      fi
      ;;
    3) echo "  # existing checkout at $LOCAL_REPO reused (linked to ~/.dotfiles if free)" ;;
  esac
  echo "  ${BUILD_CMD[*]}"
  echo "  ${ACTIVATE[*]}"
  echo "# dry-run complete."
  exit 0
fi

# --- confirmation -----------------------------------------------------------------------------

echo
echo "== Plan =="
echo "  repo: $REPO_PLAN"
echo "  env:  write $ENV_FILE"
if [ "$ENV_EXISTED" -eq 1 ]; then
  echo "        (this file EXISTS - its values were the defaults above; it will be overwritten)"
else
  echo "        (new file)"
fi
echo "  host: $HOST_LABEL"
echo
echo "== Env file contents =="
printf '%s\n' "$ENV_CONTENT"
echo
echo "The first build downloads nixpkgs + home-manager and can take a while"
echo "(a few hundred MB, several minutes); later switches are fast."
if ! confirm "Proceed?"; then
  echo "aborted - nothing was changed."
  exit 1
fi

# --- bootstrap -----------------------------------------------------------------------------------

log "Bootstrap"

# Flakes are enabled per-invocation. On NixOS /etc/nix/nix.conf is generated
# and read-only - never instruct editing it; NIX_CONFIG is the supported way.
export NIX_CONFIG="experimental-features = nix-command flakes"
info "flakes enabled for this session (NIX_CONFIG; /etc/nix/nix.conf left untouched)"

# repo_present_at <dir>: non-empty dir that looks like this repo.
repo_present_at() {
  [ -f "$1/nix/flake.nix" ] && [ -f "$1/env.example" ]
}

# unpack_repo <store-path>: copy a nix-prefetch-url --unpack result to
# ~/.dotfiles (unless a repo is already there - re-runs stay put).
unpack_repo() {
  local store="$1"
  if repo_present_at "$HOME/.dotfiles"; then
    info "reusing existing $HOME/.dotfiles (the fetched tarball stays in the nix store for the build)"
    return
  fi
  if [ -e "$HOME/.dotfiles" ] && [ -n "$(ls -A "$HOME/.dotfiles" 2>/dev/null)" ]; then
    die "$HOME/.dotfiles exists but does not look like this repo (no nix/flake.nix) - move it aside or choose a different source"
  fi
  mkdir -p "$HOME"
  if [ -d "$HOME/.dotfiles" ]; then
    cp -a "$store/." "$HOME/.dotfiles/"
  else
    cp -a "$store" "$HOME/.dotfiles"
  fi
  chmod -R u+w "$HOME/.dotfiles"
  info "unpacked the repo to $HOME/.dotfiles"
}

fetch_repo() {
  local store
  case "$SOURCE" in
    1)
      info "fetching the repo tarball from your Gitea (cached for the build)..."
      store="$(nix-prefetch-url --unpack --print-path "$LAN_URL" | tail -n 1)"
      unpack_repo "$store"
      ;;
    2)
      if [ "$HAS_GIT" -eq 1 ]; then
        if [ -e "$HOME/.dotfiles" ] && [ -n "$(ls -A "$HOME/.dotfiles" 2>/dev/null)" ]; then
          if repo_present_at "$HOME/.dotfiles"; then
            info "reusing existing $HOME/.dotfiles (no clone)"
          else
            die "$HOME/.dotfiles exists but does not look like this repo - move it aside or choose a different source"
          fi
        else
          info "cloning the public GitHub mirror to $HOME/.dotfiles..."
          git clone "$GH_URL" "$HOME/.dotfiles"
        fi
      else
        info "fetching the repo tarball from the GitHub mirror (cached for the build)..."
        store="$(nix-prefetch-url --unpack --print-path "$GH_TARBALL" | tail -n 1)"
        unpack_repo "$store"
      fi
      ;;
    3)
      if [ "$LOCAL_REPO" != "$HOME/.dotfiles" ]; then
        if [ ! -e "$HOME/.dotfiles" ]; then
          ln -s "$LOCAL_REPO" "$HOME/.dotfiles"
          info "linked $HOME/.dotfiles -> $LOCAL_REPO"
        elif [ -d "$HOME/.dotfiles" ] && [ -z "$(ls -A "$HOME/.dotfiles" 2>/dev/null)" ]; then
          rmdir "$HOME/.dotfiles"
          ln -s "$LOCAL_REPO" "$HOME/.dotfiles"
          info "linked $HOME/.dotfiles -> $LOCAL_REPO (replaced the empty dir)"
        else
          info "existing $HOME/.dotfiles is kept as-is; the build uses $LOCAL_REPO"
        fi
      else
        info "using existing checkout at $LOCAL_REPO"
      fi
      ;;
  esac
}

write_env() {
  local dir
  dir="$(dirname "$ENV_FILE")"
  if [ "$ENV_EXISTED" -eq 1 ]; then
    warn "overwriting the existing env file at $ENV_FILE (you confirmed above)"
  fi
  mkdir -p "$dir"
  printf '%s' "$ENV_CONTENT" > "$ENV_FILE"
  info "wrote $ENV_FILE"
}

fetch_repo
write_env

# Build + activation run from $HOME so ./result lands somewhere sensible
# regardless of where the script was invoked from.
cd "$HOME"

log "Build"
info "building $HOST_LABEL from $BUILD_FLAKE"
info "  (first run downloads nixpkgs + home-manager - a few hundred MB and a few minutes; later runs are fast)"
info "running: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"

log "Activate"
info "running: ${ACTIVATE[*]}"
"${ACTIVATE[@]}"

# --- summary -----------------------------------------------------------------------------------------

log "Done"

echo "What happened:"
echo "  * dotfiles repo at $UPDATE_REPO ($REPO_PLAN)"
echo "  * per-machine env file at $ENV_FILE (values from your answers above)"
echo "  * built + activated $HOST_LABEL"
if [ "$ENV_EXISTED" -eq 1 ]; then
  echo "  * your previous env file's values were kept as defaults and rewritten"
fi
echo
echo "Update this machine later:"
if [ "$IS_NIXOS" -eq 1 ]; then
  echo "  sudo nixos-rebuild switch --flake $UPDATE_REPO?dir=nix#wsl --override-input dotfiles-env path:$HOME/.config/dotfiles/env"
else
  echo "  home-manager switch --flake $UPDATE_REPO?dir=nix#server --override-input dotfiles-env path:$HOME/.config/dotfiles/env"
fi
echo "  (or just re-run $UPDATE_REPO?dir=nix/setup-wsl.sh - it re-detects everything)"
echo
echo "SSH/GPG keys and other credentials are per-machine and NOT managed by this"
echo "repo - set them up on this machine yourself (README: 'Keys and credentials')."
