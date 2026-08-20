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
  #
  # Unlike lazygit's state.yml, though, config.toml itself isn't purely user
  # config either: herdr's own binary writes to it at runtime — logs a
  # `config.write` event, overlays settings changed from the in-app `prefix+s`
  # settings UI (onboarding/sound/toast/theme.auto_switch/agent-border-labels
  # toggles), and `herdr config reset-keys` explicitly backs up and rewrites
  # it. (`onboarding = false` on line 1 of this repo's copy is itself
  # evidence — herdr wrote that after first run.) Those writes will fail
  # against this read-only nix-store symlink, or, if herdr writes via
  # temp-file-then-rename, will silently replace the symlink with a plain
  # file that gets reverted back to the nix-managed version on the next
  # `home-manager switch`.
  #
  # Unlike pi.nix's settings.json — which has a clean split between a
  # handful of nix-managed fields and "everything else is runtime", making a
  # jq merge script viable — config.toml is ~325 lines of hand-customized
  # settings with only a few fields herdr occasionally rewrites, and the
  # exact full set of those fields isn't confirmed. A partial-merge script
  # against an incompletely-known field set risks silently dropping user
  # settings, which is worse than the current symlink, so the whole-file
  # symlink stays as a deliberate, documented tradeoff: to change any herdr
  # setting, edit ~/.dotfiles/herdr/config.toml directly and run
  # `home-manager switch` — don't rely on herdr's own settings UI or
  # `reset-keys` to persist changes.
  xdg.configFile."herdr/config.toml".source = ../../../herdr/config.toml;
}
