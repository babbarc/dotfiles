# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## chezmoi source state

This repo's root **is** a standard chezmoi source directory: `dot_config/`,
`dot_pi/`, `dot_claude/`, `dot_codex/`, `.chezmoi.toml.tmpl`,
`.chezmoiignore.tmpl`, and `.chezmoiexternal.toml` all live at repo root, so
`chezmoi init --apply` against a checkout of this repo works directly, no
`--source` subdirectory needed. (How this got here: the source state was
originally built under a `chezmoi/` subdirectory gated by a `.chezmoiroot`
file, to keep chezmoi from misinterpreting the rest of the repo - which
still held a legacy pre-split home-manager flake and duplicate per-tool
config trees - as home-directory targets while the migration off that
legacy flake was in progress. Once the legacy `nix/` tree and its
repo-root duplicate trees (`nvim/`, `fish/`, etc.) were deleted, the split
had no remaining benefit and `chezmoi/`'s contents were promoted to repo
root.)

- **Every plain-named repo-root entry that isn't chezmoi source content
  (not `dot_*`/`.chezmoi*`) must be listed in `.chezmoiignore.tmpl`, or
  chezmoi's source-state scan either materializes it as a bogus literal
  target under `$HOME`, or - worse - hits a hard "inconsistent state" error
  if the name also collides with a `.chezmoiexternal.toml` entry (confirmed
  by hand, both failure modes, while promoting `chezmoi/` to repo root).**
  The current ignore list covers `pi/`, `wezterm/`, `tests/`, `containers/`,
  `tmux.conf.local`, `tmux.service`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
  `LICENSE`, and `env.example` (real repo-root content that must stay put,
  not become a `$HOME` target), plus `alacritty` (see next bullet). Adding a
  new plain-named entry at repo root means adding it here too.
- **`alacritty/catppuccin` is the one `.chezmoiexternal.toml` submodule
  entry that's an actual git gitlink in this repo's tree** (`git ls-tree`
  confirms the other 4 declared in `.gitmodules` - `.tmux`, `fzf-git.sh`,
  `passfzf`, `ohmyzsh` - have no gitlink, so they never exist as a directory
  before `git submodule update --init`, and never hit this). Because
  chezmoi's source scan covers repo root, it finds the literal (possibly
  still-uninitialized, empty) `alacritty/catppuccin` directory and collides
  with the external of the same name unless `alacritty` is in
  `.chezmoiignore.tmpl`. Ignore the *parent* name (`alacritty`, not the
  nested `alacritty/catppuccin` path) - that resolves the collision without
  disabling the external itself (confirmed by hand: with `alacritty`
  ignored, `chezmoi apply` still clones `alacritty/catppuccin` normally).
- **Per-machine values flow into chezmoi via `.chezmoi.toml.tmpl`**, which
  shells out to `cat ~/.config/dotfiles/env` and parses `KEY=VALUE` lines
  into chezmoi's own `[data]` table (Sprig `splitn`/`dict`/`stat`
  functions) - the same file wezterm/fish already read (see
  `env.example`), not a second prompted config. Missing env file (e.g. a
  fresh scratch destination) degrades to an empty data set rather than a
  template error. Templates read the values directly, e.g.
  `.DOTFILES_USER_EMAIL`, `.DOTFILES_HOST_ROLE`.
- **`.chezmoiignore.tmpl` also gates `.config/wezterm`, `.config/sway`,
  `.config/waybar` out of non-laptop roles** via `.DOTFILES_HOST_ROLE`,
  mirroring the sibling `nix-config` repo's own per-host imports split -
  keep both lists in sync if a desktop-only tool is ever added or removed
  there.
- **A chezmoi script (`run_once_`/`run_onchange_`/`modify_`) must use the
  `$CHEZMOI_DEST_DIR` env var chezmoi sets for it, never `$HOME`** - they
  coincide in normal deployment (chezmoi's destination defaults to `$HOME`),
  which is exactly why this is easy to get wrong and only surfaces when
  testing against a scratch `--destination` (confirmed by hand: the fisher
  bootstrap script silently wrote into `$HOME` during a scratch validation
  run whose `--destination` was deliberately a different directory - see
  `dot_config/fish/run_once_install-fisher.sh`).
- **`herdr/config.toml`'s `default_shell` is resolved at `chezmoi apply` time
  via `output "sh" "-c" "command -v fish"`** (see
  `dot_config/herdr/config.toml.tmpl`), replacing nix's hermetic
  `${pkgs.fish}/bin/fish` store path with whatever `fish` the *current PATH*
  resolves to. This trusts PATH ordering at apply time rather than a
  hermetic path - confirmed working on this host (resolves to
  `~/.nix-profile/bin/fish`), but re-verify after any change to how fish
  lands on PATH on a given host.
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
  `.chezmoi.toml.tmpl`) - see this repo's git history for example commands.
  This is not the only way chezmoi ever gets invoked, though: the sibling
  `nix-config` repo's `setup.sh` runs `chezmoi init`/`apply` against the
  real checkout automatically as the last step of a fresh bootstrap, right
  after nix activation succeeds (deliberately a separate scripted step, not
  wired into nix activation itself, to keep nix and chezmoi decoupled) - a
  failure there only warns, it doesn't fail the whole script.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
