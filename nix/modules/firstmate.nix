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

  home.sessionVariables = {
    FM_HOME = "${config.home.homeDirectory}/firstmate";
    # Pins the runtime backend declaratively instead of relying on
    # HERDR_ENV auto-detection, per firstmate's backend precedence
    # (docs/configuration.md: --backend flag > FM_BACKEND > config/backend
    # file > auto-detect > default tmux).
    FM_BACKEND = "herdr";
  };
}
