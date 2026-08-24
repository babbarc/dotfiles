# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## chezmoi source state (`chezmoi/`)

Phase 2 of the nix/chezmoi/agenix migration (see
`/home/yeti/firstmate/data/dotfiles-nix-chezmoi-agenix-migration-plan/report.md`
for the full plan): application dotfiles previously symlinked in by the
legacy pre-split home-manager flake (deleted; the sibling `nix-config` repo
is its successor) are now also expressed as a chezmoi source state under
`chezmoi/`, so `chezmoi apply` can materialize them independently of nix.
The original per-tool trees at repo root (`nvim/`, `wezterm/`, `fish/`, etc.)
are still there; `chezmoi/dot_config/**` etc. are separate copies,
restructured into chezmoi's naming convention, not the same files relocated.
Keep both in sync by hand until a later, separate cutover phase removes the
repo-root duplicates.

- **`.chezmoiroot` (repo root) contains the literal text `chezmoi`** - this
  repo's root also holds non-dotfile content (`README.md`, the git
  submodules, `tests/`, ...) that must never be interpreted as chezmoi target
  paths. Without `.chezmoiroot` pointing chezmoi at the `chezmoi/` subdirectory,
  `chezmoi apply --source .` treats every unprefixed repo-root entry as a
  literal target under `$HOME` (confirmed by hand: it tried to materialize
  `~/nix`, `~/README.md`, etc., and hit a hard "inconsistent state" error the
  moment a bare-named submodule dir like `alacritty/catppuccin` collided with
  its own `.chezmoiexternal.toml` entry of the same name). All of chezmoi's
  special files (`.chezmoi.toml.tmpl`, `.chezmoiignore.tmpl`,
  `.chezmoiexternal.toml`) live inside `chezmoi/`, not at the true repo root -
  only `.chezmoiroot` itself is read from the literal top.
- **Per-machine values flow into chezmoi via `chezmoi/.chezmoi.toml.tmpl`**,
  which shells out to `cat ~/.config/dotfiles/env` and parses `KEY=VALUE`
  lines into chezmoi's own `[data]` table (Sprig `splitn`/`dict`/`stat`
  functions) - the same file nix/fish/wezterm/zsh already read (see
  `env.example`), not a second prompted config. Missing env file (e.g. a
  fresh scratch destination) degrades to an empty data set rather than a
  template error. Templates read the values directly, e.g.
  `.DOTFILES_USER_EMAIL`, `.DOTFILES_HOST_ROLE`.
- **`chezmoi/.chezmoiignore.tmpl` gates `wezterm/`, `sway/`, `waybar/` out of
  non-laptop roles** via `.DOTFILES_HOST_ROLE`, mirroring
  the sibling `nix-config` repo's own per-host imports split - keep both
  lists in sync if a desktop-only tool is ever added or removed there.
- **A chezmoi script (`run_once_`/`run_onchange_`/`modify_`) must use the
  `$CHEZMOI_DEST_DIR` env var chezmoi sets for it, never `$HOME`** - they
  coincide in normal deployment (chezmoi's destination defaults to `$HOME`),
  which is exactly why this is easy to get wrong and only surfaces when
  testing against a scratch `--destination` (confirmed by hand: the fisher
  bootstrap script silently wrote into `$HOME` during a scratch validation
  run whose `--destination` was deliberately a different directory - see
  `chezmoi/dot_config/fish/run_once_install-fisher.sh`).
- **`herdr/config.toml`'s `default_shell` is resolved at `chezmoi apply` time
  via `output "sh" "-c" "command -v fish"`** (see
  `chezmoi/dot_config/herdr/config.toml.tmpl`), replacing nix's hermetic
  `${pkgs.fish}/bin/fish` store path with whatever `fish` the *current PATH*
  resolves to. This trusts PATH ordering at apply time rather than a
  hermetic path - confirmed working on this host (resolves to
  `~/.nix-profile/bin/fish`), but re-verify after any change to how fish
  lands on PATH on a given host, per the migration report's own flag on this
  exact tradeoff (§7 step 5).
- **`.chezmoiexternal.toml`'s 5 externals coexist with the real git
  submodules on purpose, for now** - both `.gitmodules` and this file declare
  the same 5 tools (`.tmux`, `fzf-git.sh`, `passfzf`,
  `alacritty/catppuccin`, `ohmyzsh`), and the actual cutover away from
  submodules is later, separate work. Target paths mirror the submodules'
  current repo-root-relative paths, now relative to `$HOME` instead.
- Validate any change here against a scratch destination, never the real
  `$HOME` or the real `~/.local/share/chezmoi`:
  `chezmoi apply --source . --destination /tmp/some-scratch --cache /tmp/some-scratch-cache --no-tty`,
  with `HOME` also pointed at a scratch dir holding a fake
  `.config/dotfiles/env` (`chezmoi init` first, to regenerate the config from
  `.chezmoi.toml.tmpl`) - see this phase's git history for the exact commands
  used. This is not the only way chezmoi ever gets invoked, though:
  the sibling `nix-config` repo's `setup.sh` now runs `chezmoi init`/`apply`
  against the real checkout automatically as the last step of a fresh
  bootstrap, right after nix activation succeeds (deliberately a separate
  scripted step, not wired into nix activation itself, to keep nix and
  chezmoi decoupled) - a failure there only warns, it doesn't fail the whole
  script.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
