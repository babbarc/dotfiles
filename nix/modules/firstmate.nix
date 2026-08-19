{ config, pkgs, ... }:
{
  # ~/firstmate is a plain git clone (github:kunchenguid/firstmate), not
  # nix-tracked — same posture as ~/.dotfiles itself and wezterm's upstream
  # config clone (see wezterm.nix). Update it via firstmate's own
  # /updatefirstmate skill or `git pull`, not via this module.
  #
  # Pi's firstmate-supervision watcher extension lives inside that clone
  # (~/firstmate/.pi/extensions/*.ts) and auto-loads once `pi` is launched
  # from ~/firstmate and the project trust prompt is approved once — no nix
  # wiring needed for it.
  home.packages = with pkgs; [
    gh   # firstmate requires `gh auth login` for PR creation
    jq   # required by the herdr runtime backend for JSON responses
  ];

  # home.sessionVariables only reaches interactive shells (via
  # hm-session-vars) — same gap nix/modules/session-path.nix documents for
  # PATH: systemd --user never sources that file, so anything launched
  # outside a shell wouldn't see these. Not an issue today since firstmate
  # and herdr are both terminal-launched here, not GUI-launched. If that ever
  # changes (a .desktop entry, a systemd unit), FM_HOME/FM_BACKEND would need
  # their own environment.d fix the way session-path.nix does for PATH.
  home.sessionVariables = {
    FM_HOME = "${config.home.homeDirectory}/firstmate";
    # Pins the runtime backend declaratively instead of relying on
    # HERDR_ENV auto-detection, per firstmate's backend precedence
    # (docs/configuration.md: --backend flag > FM_BACKEND > config/backend
    # file > auto-detect > default tmux).
    FM_BACKEND = "herdr";
  };
}
