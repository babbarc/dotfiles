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
  The current ignore list covers `wezterm/`, `tests/`, `containers/`,
  `README.md`, `AGENTS.md`, `CLAUDE.md`,
  `LICENSE`, and `env.example` (real repo-root content that must stay put,
  not become a `$HOME` target). Adding a new plain-named entry at repo root
  means adding it here too.
- **Per-machine values flow into chezmoi via `.chezmoi.toml.tmpl`**, which
  shells out to `cat ~/.config/dotfiles/env` and parses `KEY=VALUE` lines
  into chezmoi's own `[data]` table (Sprig `splitn`/`dict`/`stat`
  functions) - the same file wezterm/fish already read (see
  `env.example`), not a second prompted config. Missing env file (e.g. a
  fresh scratch destination) degrades to an empty data set rather than a
  template error. Templates read the values directly, e.g.
  `.DOTFILES_HOST_ROLE`.
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
- **`.chezmoiexternal.toml`'s single external coexists with the real git
  submodule on purpose, for now** - both `.gitmodules` and this file declare
  `fzf-git.sh`; `ohmyzsh`, `.tmux`, and `passfzf` were removed (the shell is
  fish, the multiplexer is herdr, and passfzf is unused). fzf-git.sh is
  sourced by `dot_config/fish/conf.d/fzf-git.fish`. The target path mirrors
  the submodule's repo-root-relative path, now relative to `$HOME`.
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

## Agent config ownership boundary with nix-config

dotfiles owns all `~/.pi`, `~/.claude`, `~/.codex` config content; the
sibling `nix-config` repo carries packages and tool installers only
(including the guide's 3rd-party Pi extensions from
[Kun's Pi Agent Config](https://blog.kunchenguid.com/p/kuns-pi-agent-config)).

- **`dot_pi/agent/create_models.json`** seeds `~/.pi/agent/models.json` via
  chezmoi's `create_` attribute: created only if absent, never modified
  again - so a hand edit survives every future `chezmoi apply` forever.
  This is the one deliberate exception to "dotfiles owns everything": once
  seeded, `models.json` is the captain's own file to tweak.
- **`dot_pi/agent/modify_settings.json` and `dot_claude/modify_settings.json`**
  share one contract (see the comment atop each): chezmoi feeds the existing
  target file on stdin, the script merges its own small default set on top
  with `jq '. * $defaults'`, and prints the result on stdout - existing
  content wins on every key the script doesn't declare, so runtime-written
  fields (pi's `defaultProvider`/`packages`, Claude Code's hooks) always
  survive. Neither script declares `packages` or `extensions`: pi owns its
  `packages` array and nix-config owns extension registration.
- Both `dot_claude/symlink_CLAUDE.md.tmpl` and `dot_codex/symlink_AGENTS.md.tmpl`
  point at `~/.pi/agent/AGENTS.md`; a broken symlink there almost always
  means that file went missing or `dot_pi/agent/AGENTS.md` was renamed.
- `tests/agent-config.test.sh` pins all three (the two merge scripts
  directly, and the create-only seed via a real scratch `chezmoi apply`
  cycle) - extend it, not a fresh ad hoc script, for related changes.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
