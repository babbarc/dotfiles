{ ... }:
{
  # herdr itself is deliberately outside Nix (not in nixpkgs, no binary
  # cache, would require a from-source build — see the parent nix-migration
  # project's Task 9). It stays installed via its own curl installer at
  # ~/.local/bin/herdr, self-updating via `herdr update` / `herdr channel
  # set`. This module never touches the binary.
  #
  # Only config.toml is genuinely user config. session.json, .plugins.lock,
  # and the two .log files are runtime-written and stay unmanaged plain
  # files — same split already used for lazygit's config.yml/state.yml.
  xdg.configFile."herdr/config.toml".source = ../../herdr/config.toml;
}
