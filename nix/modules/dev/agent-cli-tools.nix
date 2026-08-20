{ ... }:
{
  # treehouse, no-mistakes, and the axi suite (gh-axi, chrome-devtools-axi,
  # lavish-axi, tasks-axi, quota-axi) plus gnhf follow the same posture as
  # herdr.nix: none are in nixpkgs, none have a binary cache, and each already
  # ships its own update path — building them from source in Nix would fight
  # that update path on every release instead of using it. This module is
  # documentation plus the one-time bootstrap, not a package definition; it
  # never touches the binaries.
  #
  # Install once per machine (npm-global.nix must land first so the npm
  # installs below have a writable prefix):
  #   curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
  #   curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
  #   npm install -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf
  #
  # Update:
  #   treehouse update
  #   curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh   (no separate update command)
  #   npm update -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf
}
