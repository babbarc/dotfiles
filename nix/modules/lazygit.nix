{ ... }:
{
  # ~/.config/lazygit used to be a whole-directory symlink to
  # ~/.dotfiles/lazygit, which held both config.yml (user config) and
  # state.yml (lazygit's own runtime state — recent repos, command history —
  # confirmed actively written by its mtime). Only config.yml is genuinely
  # user config, so only it is brought under home-manager management here.
  # state.yml is deliberately left out: it was copied out to a plain local
  # file at ~/.config/lazygit/state.yml (not symlinked anywhere, and not
  # re-synced to the git-tracked copy in this repo) so lazygit can keep
  # writing to it on every run without hitting a read-only Nix-store symlink.
  xdg.configFile."lazygit/config.yml".source = ../../lazygit/config.yml;
}
