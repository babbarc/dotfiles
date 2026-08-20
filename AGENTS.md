# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Nix / home-manager (`nix/`)

- `nix/flake.nix` targets `homeConfigurations.USERNAME`. Validate changes with
  `nix build ./nix#homeConfigurations.USERNAME.activationPackage --no-link` (from repo root) -
  it builds without touching the live system. The live deployed copy is a separate checkout at
  `~/.dotfiles`, updated out of band via `home-manager switch` there.
- Flakes only see git-tracked files. A new file under `nix/modules/` (or any path the flake
  reads) must be `git add`-ed (at least `git add -N` for an empty placeholder) before
  `nix build`/`nix flake` will notice it - otherwise you get a confusing
  "in the left operand of the update (//) operator" eval error from home-manager's internals
  instead of a clear "file not found".
  - Dotfiles get pulled under home-manager management by adding a small module in
  `nix/modules/<app>.nix` that maps each file via
  `xdg.configFile."<app>/<relative-path>".source = ../../<app>/<relative-path>;`, then adding
  that module to the `imports` list in `nix/home.nix`. See `nix/modules/wezterm.nix`,
  `nix/modules/sway.nix`, `nix/modules/waybar.nix` for examples. Before wiring up a new app this
  way, check whether its config files reference each other or other config by absolute
  `~/.config/...` path - that breaks once home-manager replaces them with read-only Nix-store
  symlinks (wezterm.nix's header comment documents a real instance of this class of problem).

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
