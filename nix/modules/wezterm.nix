{ ... }:
{
  # ~/.config/wezterm is a separate git clone of the upstream
  # KevinSilvester/wezterm-config framework, not part of this repo. These 5 files
  # are the only ones that diverge from upstream (the rest of that clone — utils/,
  # events/, backdrops/, colors/custom.lua — matches upstream exactly and is left
  # alone, still updated via that repo's own `git pull`).
  #
  # That repo has `git update-index --skip-worktree` set on these 5 paths so its
  # `git status` stays clean despite home-manager replacing them with symlinks —
  # do not `git add`/`git rm --cached` them there, and do not commit in that repo.
  #
  # CAUTION: skip-worktree does not fully protect against `git pull`/rebase
  # overwriting these files if upstream also changes them (that guarantee needs
  # core.sparseCheckout too, which isn't set up here). ~/.config/wezterm was 2
  # commits behind origin/master as of this migration, and one of those unpulled
  # commits touches config/appearance.lua. After any future `git pull` there,
  # re-run `git update-index --skip-worktree config/*.lua` on these 5 paths and
  # `home-manager switch` to restore the Nix-managed symlinks if they got clobbered.
  xdg.configFile = {
    "wezterm/config/appearance.lua".source = ../../wezterm/config/appearance.lua;
    "wezterm/config/bindings.lua".source = ../../wezterm/config/bindings.lua;
    "wezterm/config/domains.lua".source = ../../wezterm/config/domains.lua;
    "wezterm/config/fonts.lua".source = ../../wezterm/config/fonts.lua;
    "wezterm/config/launch.lua".source = ../../wezterm/config/launch.lua;
  };
}
