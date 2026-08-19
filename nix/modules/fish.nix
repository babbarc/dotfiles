{ fisher, ... }:
{
  # programs.fish.enable is already set in home.nix (Task 1).
  #
  # fisher itself: originally left pacman-managed since it isn't packaged in
  # nixpkgs. Revisited later — fisher's entire pacman package is just two
  # plain fish files (functions/fisher.fish, completions/fisher.fish), no
  # binary, no build. pacman only blocked removing its own `fish` package
  # because *its* fisher package declares a `fish` dependency in pacman's
  # metadata — a packaging artifact, not a real technical requirement (fisher
  # is plain fish scripting, no fish-version-specific internals). So instead
  # of relying on nixpkgs packaging fisher, its two files are fetched directly
  # from upstream via the `fisher` flake input (a non-flake source fetch, see
  # flake.nix) and placed exactly where pacman's package used to put them.
  # Fisher's actual plugin-management behavior (fisher install/update writing
  # into conf.d/functions/completions) is unchanged — only fisher's own
  # bootstrap moved to Nix.

  # NOTE ON A REAL REGRESSION FOUND AND FIXED HERE: this module originally used
  # `xdg.configFile."fish/config.fish".source = lib.mkForce ../../fish/config.fish;`
  # to fully replace home-manager's own generated config.fish with the user's
  # original file. That silently dropped the PATH-setup sourcing home-manager's
  # fish integration normally writes into config.fish (the bit that adds
  # ~/.nix-profile/bin to PATH) — so no Nix-installed package's binary was
  # reachable by bare name in ANY fish shell, interactive or login, for as long
  # as that mkForce was in place. It went unnoticed because every fish-based
  # `which <tool>` check in earlier tasks happened to hit a pacman-installed
  # fallback of the same tool. Fixed by using `programs.fish.interactiveShellInit`
  # instead, which lets home-manager keep generating config.fish (PATH setup
  # included) while still injecting the user's own two lines into it.
  programs.fish.interactiveShellInit = ''
    starship init fish | source
    set -g fish_greeting
  '';

  xdg.configFile = {
    "fish/functions/fisher.fish".source = "${fisher}/functions/fisher.fish";
    "fish/completions/fisher.fish".source = "${fisher}/completions/fisher.fish";
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
