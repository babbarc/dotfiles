#!/usr/bin/env bash
# nix/setup-server.sh - bootstrap a fresh standalone home-manager host.
#
# One straight-line bootstrap for a freshly-installed Arch-style host (laptop or
# server): enable Nix flakes, pre-flight the repo for the pure-eval symlink
# trap, then build and activate the host's home-manager activation package.
# No wrappers, no config layers.
#
# The flake lives in the nix/ SUBDIRECTORY, so the ref must use the repo-root
# ?dir=nix form (dev modules climb up to repo-root files). Nix ignores
# ?dir=nix on a bare path, so a LOCAL ref must start with the path: scheme:
#   path:$REPO?dir=nix#homeConfigurations.<host>.activationPackage
# (remote URLs need no path: prefix).
# and activation needs HOME_MANAGER_BACKUP_EXT so pre-existing files are renamed
# instead of deleted.
#
# Usage:
#   setup-server.sh [--impure] [--dry-run] [host]
#
#   host       homeConfigurations name (laptop or server). If omitted,
#              auto-detected from DOTFILES_HOST_ROLE in the per-machine env
#              file (~/.config/dotfiles/env), with a hostname fallback.
#   --impure   proceed even if the repo has stray symlinks that break pure eval
#              (passes --impure to nix build).
#   --dry-run  run only the pre-flight checks and print the commands that would
#              run - no sudo, no build, no activation.
#
# Requires the per-machine env file ~/.config/dotfiles/env (copy the committed
# env.example and edit it); it is passed to the flake via
# --override-input dotfiles-env path:$HOME/.config/dotfiles/env so pure
# evaluation stays intact.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: setup-server.sh [--impure] [--dry-run] [host]

Bootstraps a fresh standalone home-manager host (laptop or server).

  host       homeConfigurations name (defaults to auto-detection from
             DOTFILES_HOST_ROLE in the per-machine env file, then hostname)
  --impure   proceed even if the repo has stray symlinks that break pure eval
  --dry-run  run only the pre-flight checks and print commands, run nothing
EOF
  exit 1
}

IMPURE=0
DRY_RUN=0
HOST=""

for arg in "$@"; do
  case "$arg" in
    --impure) IMPURE=1 ;;
    --dry-run | --check) DRY_RUN=1 ;;
    --help | -h) usage ;;
    -*)
      echo "error: unknown option: $arg" >&2
      usage
      ;;
    *)
      if [ -n "$HOST" ]; then
        echo "error: only one host name may be given ('$HOST' and '$arg')" >&2
        usage
      fi
      HOST="$arg"
      ;;
  esac
done

# Repo root is the parent of this script's directory (the script lives in nix/).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- per-machine env file ---------------------------------------------------

# Machine-specific personal values (usernames, hostnames, LAN endpoints) live
# in ~/.config/dotfiles/env on each machine, copied from the committed
# env.example at the repo root. The nix build below feeds it to the flake via
# --override-input dotfiles-env path:$ENV_FILE so pure evaluation stays intact
# (nix can't read the file directly in pure mode). DOTFILES_ENV_FILE overrides
# the location for testing.
ENV_FILE="${DOTFILES_ENV_FILE:-$HOME/.config/dotfiles/env}"

# --- resolve the host -------------------------------------------------------

VALID_HOSTS=(laptop server)
is_valid_host() {
  local h
  for h in "${VALID_HOSTS[@]}"; do
    [ "$h" = "$1" ] && return 0
  done
  return 1
}

# The build needs the env file (the --override-input below); fail fast with
# clear guidance instead of letting nix error cryptically.
if [ ! -f "$ENV_FILE" ]; then
  echo "error: per-machine env file not found: $ENV_FILE" >&2
  echo "       Copy the committed example and edit it for this host first:" >&2
  echo "         cp \"$REPO/env.example\" \"$ENV_FILE\"" >&2
  echo "       At minimum set DOTFILES_HOST_ROLE (one of ${VALID_HOSTS[*]}) and" >&2
  echo "       DOTFILES_USERNAME; see the comments in env.example for the rest." >&2
  exit 1
fi

if [ -z "$HOST" ]; then
  # DOTFILES_HOST_ROLE from the per-machine env file (later lines win) ...
  HOST="$(sed -n 's/^DOTFILES_HOST_ROLE=//p' "$ENV_FILE" | tail -n 1 | xargs)"
  # ... then a hostname-based fallback for the first bootstrap, while the env
  # file's role line is still unset.
  if [ -z "$HOST" ]; then
    case "$(hostname)" in
      laptop) HOST=laptop ;;
    esac
  fi
  if [ -z "$HOST" ]; then
    echo "error: could not auto-detect host role from \`hostname\` ($(hostname))." >&2
    printf 'pass it explicitly (e.g. setup-server.sh server) or set DOTFILES_HOST_ROLE in %s.\n' "$ENV_FILE" >&2
    printf 'valid host names: %s\n' "${VALID_HOSTS[*]}" >&2
    exit 1
  fi
  echo "auto-detected host: $HOST"
fi

if ! is_valid_host "$HOST"; then
  echo "error: unknown host '$HOST'." >&2
  printf 'valid host names: %s\n' "${VALID_HOSTS[*]}" >&2
  exit 1
fi

# --- experimental features ---------------------------------------------------

# A fresh Nix install often ships without the experimental features enabled, so
# every command needs --extra-experimental-features 'nix-command flakes'
# gymnastics. Ensure /etc/nix/nix.conf sets them (idempotent, needs sudo).

NIX_CONF=/etc/nix/nix.conf
features_set=0
if [ -f "$NIX_CONF" ] && grep -Eq '^[[:space:]]*experimental-features[ =].*nix-command.*flakes' "$NIX_CONF"; then
  features_set=1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$features_set" -eq 1 ]; then
    echo "# ok: $NIX_CONF already has 'experimental-features = nix-command flakes'"
  else
    echo "# would run (needs sudo): ensure $NIX_CONF contains:"
    echo "#   experimental-features = nix-command flakes"
  fi
elif [ "$features_set" -eq 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "error: 'experimental-features = nix-command flakes' is missing from $NIX_CONF," >&2
    echo "       but sudo is not available to fix it." >&2
    echo "       Run as root or add the line to $NIX_CONF yourself, then re-run." >&2
    exit 1
  fi
  sudo mkdir -p /etc/nix
  if ! sudo grep -Eq '^[[:space:]]*experimental-features[ =].*nix-command.*flakes' "$NIX_CONF" 2>/dev/null; then
    echo 'experimental-features = nix-command flakes' | sudo tee -a "$NIX_CONF" >/dev/null
    echo "enabled 'experimental-features = nix-command flakes' in $NIX_CONF"
  fi
fi

# --- robust fish Nix PATH hook -----------------------------------------------

# Nix's installer-created /etc/fish/conf.d/nix.fish sources nix-daemon.fish, whose
# per-user-profile `add_path "$NIX_LINK/bin"` silently fails during fish login
# startup - so ~/.nix-profile/bin (where home-manager-path installs every tool)
# never lands on PATH in a clean ssh login. A robust hook adds both profile dirs
# directly, independent of that buggy script; $HOME expands per-user at runtime.
# The home-manager-managed fish/conf.d/nix-path.fish (nix/modules/dev/fish.nix)
# already covers the home-manager user; this system hook covers every user on the
# machine. The stock hook contains `nix-daemon.fish`; the robust one does not.

FISH_NIX_HOOK=/etc/fish/conf.d/nix.fish
FISH_HOOK_CONTENT='# Nix
fish_add_path --prepend --global "$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin
# End Nix
'
fish_hook_ok=0
if [ -f "$FISH_NIX_HOOK" ] && grep -q 'nix-daemon.fish' "$FISH_NIX_HOOK"; then
  : # stock nix-installer hook - needs replacing
elif [ -f "$FISH_NIX_HOOK" ] && grep -Fq 'fish_add_path --prepend --global "$HOME/.nix-profile/bin"' "$FISH_NIX_HOOK"; then
  fish_hook_ok=1
fi

# A missing/unfixable system hook does NOT block the bootstrap: home-manager's
# managed fish/conf.d/nix-path.fish already covers the main user. So warn, don't fail.
if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$fish_hook_ok" -eq 1 ]; then
    echo "# ok: $FISH_NIX_HOOK already has the robust fish Nix PATH hook"
  else
    echo "# would write $FISH_NIX_HOOK:"
    printf '%s' "$FISH_HOOK_CONTENT" | sed 's/^/#   /'
  fi
elif [ "$fish_hook_ok" -eq 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "warning: $FISH_NIX_HOOK is missing the robust Nix PATH hook and sudo is" >&2
    echo "         unavailable to write it; home-manager's managed fish/conf.d" >&2
    echo "         still covers the main user, so continuing." >&2
  else
    sudo mkdir -p /etc/fish/conf.d
    printf '%s' "$FISH_HOOK_CONTENT" | sudo tee "$FISH_NIX_HOOK" >/dev/null
    echo "wrote the robust fish Nix PATH hook to $FISH_NIX_HOOK"
  fi
fi

# --- pre-flight: pure-eval symlink trap --------------------------------------

# A legacy symlink-based dotfiles deployment can leave files in the repo
# pointing into /nix/store (or ~/.config). Nix evaluates the flake in pure mode,
# where reading an absolute store path is forbidden:
#   error: access to absolute path '<store>' is forbidden in pure evaluation
#          mode (use '--impure' to override)
# Fix: `git checkout -- <tracked path>`, or delete the gitignored ones (e.g.
# nvim/lazy-lock.json).

# Exclude the build's own ./result symlink (it points into /nix/store) so a
# re-run on an already-built repo isn't flagged.
SYMLINKS=()
while IFS= read -r -d '' link; do
  SYMLINKS+=("$link")
done < <(find "$REPO" -type l -not -path "$REPO/.git/*" -not -path "$REPO/result" -print0)

if [ "${#SYMLINKS[@]}" -gt 0 ]; then
  echo "error: found ${#SYMLINKS[@]} symlink(s) in the repo that would break pure evaluation:" >&2
  for link in "${SYMLINKS[@]}"; do
    rel="${link#"$REPO"/}"
    printf '  %s -> %s\n' "$rel" "$(readlink "$link")" >&2
    if git -C "$REPO" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
      printf '    fix: git checkout -- %s\n' "$rel" >&2
    else
      # `git clean -fd` won't remove gitignored files (needs -x); rm is explicit
      # and honest here. nvim/lazy-lock.json is the canonical gitignored one.
      printf '    fix: rm %s   (untracked/gitignored, e.g. nvim/lazy-lock.json)\n' "$rel" >&2
    fi
  done
  echo >&2
  echo "Nix builds in pure mode by default, and a symlink to an absolute store path" >&2
  echo "makes it fail with:" >&2
  echo "  error: access to absolute path '<store>' is forbidden in pure" >&2
  echo "         evaluation mode (use '--impure' to override)" >&2
  echo >&2
  if [ "$IMPURE" -eq 1 ]; then
    echo "warning: proceeding anyway because --impure was passed." >&2
  else
    echo "stop: fix the symlinks above, or pass --impure to force the build anyway." >&2
    exit 1
  fi
fi

# --- dry-run: print what would run, then stop --------------------------------

BUILD_REF="path:$REPO?dir=nix#homeConfigurations.$HOST.activationPackage"
BUILD_ARGS=(--override-input dotfiles-env "path:$ENV_FILE")
[ "$IMPURE" -eq 1 ] && BUILD_ARGS+=(--impure)

if [ "$DRY_RUN" -eq 1 ]; then
  echo "# would run (host=$HOST):"
  echo "  nix build ${BUILD_ARGS[*]} $BUILD_REF"
  echo "  HOME_MANAGER_BACKUP_EXT=backup ./result/activate"
  echo "  gh auth login    # manual, interactive"
  echo "# dry-run complete - nothing was built or activated."
  exit 0
fi

# --- build and activate ------------------------------------------------------

echo "building: nix build ${BUILD_ARGS[*]} $BUILD_REF"
cd "$REPO"
nix build "${BUILD_ARGS[@]}" "$BUILD_REF"

echo "activating host '$HOST' (old files backed up as *.backup)..."
HOME_MANAGER_BACKUP_EXT=backup ./result/activate

# --- reminders ---------------------------------------------------------------

echo
echo "Reminders:"
echo "  * gh auth login - interactive OAuth device flow, must be done by hand."
echo "  * If any self-bootstrapping tool (firstmate/herdr/treehouse/no-mistakes/"
echo "    axi) printed an install warning, re-run the switch once you're back"
echo "    online to retry its installer - see the 'After the switch' section of"
echo "    the README."
echo
echo "Done: host '$HOST' built and activated. Pre-existing files were backed up"
echo "with a .backup suffix (HOME_MANAGER_BACKUP_EXT=backup)."
