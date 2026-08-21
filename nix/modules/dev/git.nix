{ config, ... }:
{
  # Global git identity, shared across all three hosts. userName reuses
  # config.home.username rather than reading dotfilesEnv.DOTFILES_USERNAME
  # directly - every host's home.nix/configuration.nix already sets
  # home.username to that same per-machine value (it's also what
  # nix/hosts/wsl/configuration.nix feeds to wsl.defaultUser for the WSL
  # user account), so this stays in sync with the WSL username by
  # construction instead of duplicating the env lookup.
  #
  # userEmail is deliberately left unset: no email for this user is recorded
  # anywhere in this repo. Set it per-machine with
  # `git config --global user.email you@example.com`, or add a
  # `programs.git.userEmail` line here once one exists to record.
  programs.git = {
    enable = true;
    settings.user.name = config.home.username;
  };
}
