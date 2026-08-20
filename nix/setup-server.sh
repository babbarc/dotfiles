#!/usr/bin/env bash
# nix/setup-server.sh - bootstrap a fresh standalone home-manager host.
#
# One straight-line bootstrap for a freshly-installed Arch-style host (laptop or
# server): enable Nix flakes, pre-flight the repo for the pure-eval symlink
# trap, then build and activate the host's home-manager activation package.
# No wrappers, no config layers.
#
# The flake lives in the nix/ SUBDIRECTORY, so the ref is
#   <repo>/nix#homeConfigurations.<host>.activationPackage
# and activation needs HOME_MANAGER_BACKUP_EXT so pre-existing files are renamed
# instead of deleted.
#
# Usage:
#   setup-server.sh [--impure] [--dry-run] [host]
#
#   host       homeConfigurations name (laptop or server). If omitted,
#              auto-detected from `hostname`.
#   --impure   proceed even if the repo has stray symlinks that break pure eval
#              (passes --impure to nix build).
#   --dry-run  run only the pre-flight checks and print the commands that would
#              run - no sudo, no build, no activation.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: setup-server.sh [--impure] [--dry-run] [host]

Bootstraps a fresh standalone home-manager host (laptop or server).

  host       homeConfigurations name (defaults to auto-detection from hostname)
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

# --- resolve the host ---------------------------------------------------------

VALID_HOSTS=(laptop server)
is_valid_host() {
  local h
  for h in "${VALID_HOSTS[@]}"; do
    [ "$h" = "$1" ] && return 0
  done
  return 1
}

if [ -z "$HOST" ]; then
  case "$(hostname)" in
    laptop) HOST=laptop ;;
    HOSTNAME) HOST=server ;;
    *)
      echo "error: could not auto-detect host from \`hostname\` ($(hostname))." >&2
      printf 'valid host names: %s\n' "${VALID_HOSTS[*]}" >&2
      exit 1
      ;;
  esac
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

BUILD_REF="$REPO/nix#homeConfigurations.$HOST.activationPackage"
BUILD_ARGS=()
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
