#!/bin/sh
# Fisher itself isn't a personal dotfile - it's a two-file bootstrap
# (functions/fisher.fish, completions/fisher.fish) that nix/modules/dev/fish.nix
# used to fetch via a flake input (github:jorgebucaran/fisher, flake = false).
# Now that fish/ is chezmoi-owned, this run_once_ script fetches the same two
# files directly from upstream, matching the curl-install pattern used
# elsewhere in this repo for tools with no nixpkgs entry (see
# nix/modules/dev/agent-cli-tools.nix, read-only reference - not touched by
# this migration). run_once_ only re-runs when this script's own contents
# change, so a fresh fisher release doesn't refetch on every apply; delete
# ~/.config/fish/functions/fisher.fish to force a manual refetch.
set -eu

# CHEZMOI_DEST_DIR (not $HOME) is the actual apply target - they coincide in
# normal deployment, but relying on $HOME broke this script under a scratch
# --destination during validation, which is the whole point of testing it
# that way.
fish_conf_dir="${CHEZMOI_DEST_DIR}/.config/fish"
mkdir -p "${fish_conf_dir}/functions" "${fish_conf_dir}/completions"

curl -fsSL -o "${fish_conf_dir}/functions/fisher.fish" \
  https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish
curl -fsSL -o "${fish_conf_dir}/completions/fisher.fish" \
  https://raw.githubusercontent.com/jorgebucaran/fisher/main/completions/fisher.fish
