{ lib, ... }:
{
  # lazy.nvim writes to lazy-lock.json on `:Lazy update`; a Nix-store-backed
  # symlink would be read-only and break that, so it's deliberately excluded
  # from xdg.configFile below (5 entries here, not 6 — not an oversight).
  # Instead it gets a plain symlink back into the git-tracked file, recreated
  # idempotently by the activation script below so it survives a fresh
  # `home-manager switch` without depending on anyone remembering a manual step.
  xdg.configFile = {
    "nvim/init.lua".source = ../../nvim/init.lua;
    "nvim/lazyvim.json".source = ../../nvim/lazyvim.json;
    "nvim/stylua.toml".source = ../../nvim/stylua.toml;
    "nvim/lua" = {
      source = ../../nvim/lua;
      recursive = true;
    };
    "nvim/snippets" = {
      source = ../../nvim/snippets;
      recursive = true;
    };
  };

  home.activation.nvimLazyLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/nvim"
    run ln -sf "$HOME/.dotfiles/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
  '';
}
