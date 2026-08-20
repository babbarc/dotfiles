{ config, pkgs, ... }:
{
  home.username = "USERNAME";
  home.homeDirectory = "/home/USERNAME";

  # Pin to the home-manager release this config was first created against.
  # Do not bump this when nixpkgs/home-manager update later — see home-manager's
  # documentation on stateVersion for why.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
  programs.fish.enable = true;

  imports = [
    ./modules/cli-tools.nix
    ./modules/dev-toolchains.nix
    ./modules/fish.nix
    ./modules/session-path.nix
    ./modules/wezterm.nix
    ./modules/sway.nix
    ./modules/waybar.nix
    ./modules/nvim.nix
    ./modules/lazygit.nix
    ./modules/firstmate.nix
    ./modules/npm-global.nix
    ./modules/agent-cli-tools.nix
    ./modules/herdr.nix
    ./modules/pi.nix
    ./modules/voice-dictation.nix
    ./modules/fonts.nix
  ];
}
