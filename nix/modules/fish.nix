{ lib, ... }:
{
  # programs.fish.enable is already set in home.nix (Task 1).
  # fisher itself stays pacman-managed (fisher 4.4.8-1) — it isn't packaged
  # in nixpkgs; only fish's config content is migrated here.

  xdg.configFile = {
    # home-manager's own fish module (programs.fish.enable) also defines
    # xdg.configFile."fish/config.fish" (that's what took over the plain
    # file in Task 1) — mkForce so our user-authored content wins.
    "fish/config.fish".source = lib.mkForce ../../fish/config.fish;
    "fish/conf.d/fish_frozen_theme.fish".source = ../../fish/conf.d/fish_frozen_theme.fish;
    "fish/conf.d/fish_frozen_key_bindings.fish".source = ../../fish/conf.d/fish_frozen_key_bindings.fish;
    "fish/functions/fish_greeting.fish".source = ../../fish/functions/fish_greeting.fish;
    "fish/functions/joy-console.fish".source = ../../fish/functions/joy-console.fish;
    "fish/functions/rgf.fish".source = ../../fish/functions/rgf.fish;
    "fish/functions/s.fish".source = ../../fish/functions/s.fish;
    "fish/themes" = {
      source = ../../fish/themes;
      recursive = true;
    };
  };
}
