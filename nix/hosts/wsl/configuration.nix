# NixOS-WSL host for the Windows machine's WSL2 distro. Unlike the Arch host
# (nix/home.nix), which runs home-manager standalone because Arch isn't NixOS
# and has nothing for a home-manager NixOS module to attach to, this host IS a
# NixOS system - so home-manager is wired in here as a NixOS module
# (home-manager.nixosModules.home-manager, imported in flake.nix) instead.
# That gives one `nixos-rebuild switch` for both system and home, which is the
# standard pattern for a single-user NixOS-WSL machine and avoids running two
# separate switch commands for one host.
#
# Only the shared nix/modules/dev - portable dev tooling with no display
# server or Arch-specific assumptions - is imported here. Secrets and machine
# identity (SSH/GPG keys) are not managed by this repo on any host; set those
# up on the WSL machine itself, same as the Arch host.
{ config, lib, pkgs, fisher, ... }:
{
  imports = [
    # nixos-wsl.nixosModules.default and home-manager.nixosModules.home-manager
    # are imported at the flake level (nix/flake.nix), not here.
  ];

  wsl.enable = true;
  wsl.defaultUser = "USERNAME";

  # Matches nix/flake.nix's allowUnfreePredicate for the Arch host's own pkgs
  # instance (unrar, pulled in by modules/dev/cli-tools.nix) - this host has
  # no custom `pkgs` passed to nixosSystem, so the same exception has to be
  # set here instead, via the module system.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "unrar" ];

  # Matches nix/home.nix's home.stateVersion - do not bump either without
  # reading home-manager's stateVersion documentation first.
  system.stateVersion = "24.11";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit fisher; };
  home-manager.users.USERNAME = {
    home.username = "USERNAME";
    home.homeDirectory = "/home/USERNAME";
    home.stateVersion = "24.11";
    programs.home-manager.enable = true;

    imports = [ ../../modules/dev ];
  };
}
