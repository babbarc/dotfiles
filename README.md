# dotfiles

Personal Linux dotfiles, managed with chezmoi and consumed by the sibling
`nix-config` repo's Nix home-manager flake as the last step of its own
bootstrap.

These are personal dotfiles, shared publicly so people can read them, learn
from them, and fork them freely.

## Fresh machine setup

The bootstrap entrypoint lives in the sibling `nix-config` repo, not here:
its own `setup.sh` builds and activates the right host (laptop, server, or
wsl), then as its final step applies this repo's chezmoi-managed dotfiles
against `~/.dotfiles`. See `nix-config`'s own README for the guided
bootstrap flow. This repo is chezmoi's source of truth for dotfile content;
see "Repo layout" below.

## What you get

Running the switch builds:

- **Shell** - fish with custom key bindings and functions
- **Editor** - Neovim (lazyvim) with the rose-pine-moon theme
- **Terminal** - WezTerm (rose-pine-moon theme, dimmed unfocused windows)
- **Agent configs** - pi, Claude Code, and Codex all share one `AGENTS.md`
- **Pi** - the rose-pine-moon theme, the Calm extension, and generic UI settings
- **herdr** - tmux-style key bindings and agent panel layout
- **Other tools** - lazygit, alacritty, sway, waybar, tmux, fonts, dev toolchains

## Repo layout

This repo's root is itself a standard chezmoi source directory - clone it
and run `chezmoi init --apply` and it just works, no subdirectory or
`--source` flag needed (though in practice `nix-config`'s `setup.sh` is
what actually drives it - see "Fresh machine setup" above).

```
dot_config/            chezmoi source for ~/.config: fish, git, herdr,
                        lazygit, nvim (lazyvim), starship.toml, sway,
                        waybar, wezterm - the complete, self-contained
                        wezterm config (no external framework dependency)
dot_pi/                chezmoi source for ~/.pi (merges pi's settings.json,
                        symlinks AGENTS.md/extensions/themes into pi/ below)
dot_claude/            chezmoi source for ~/.claude (symlinks CLAUDE.md into
                        pi/AGENTS.md below)
dot_codex/             chezmoi source for ~/.codex (symlinks AGENTS.md into
                        pi/AGENTS.md below)
.chezmoi.toml.tmpl     parses ~/.config/dotfiles/env into chezmoi template data
.chezmoiignore.tmpl    host-role gating (desktop-only tools) + excludes every
                        non-chezmoi repo-root entry below from chezmoi's scan
.chezmoiexternal.toml  chezmoi-managed mirrors of this repo's git submodules
pi/                    Pi agent files: AGENTS.md, theme, extensions (incl.
                        Calm) - the canonical source dot_pi/ symlinks into
wezterm/               setup-windows.ps1 only (one-click Windows wezterm
                        setup, fetches dot_config/wezterm/ by literal path -
                        not chezmoi-managed, Windows doesn't run chezmoi)
tmux.conf.local        tmux configuration
tests/                 Behavior tests, incl. the Pi Calm suite
env.example            Template for the per-machine env file (see below)
```

## Agent instructions

`pi/AGENTS.md` is the single source of truth for global agent behavior. It is
symlinked by chezmoi into `~/.pi/agent/AGENTS.md` (pi), `~/.claude/CLAUDE.md`
(Claude Code), and `~/.codex/AGENTS.md` (Codex). Edit the one file; every
agent picks it up on its next session.

The Pi Calm extension (`pi/extensions/calm`) is a conversation-presentation
toggle for pi: `/calm` hides collapsed thinking and tool-call shells so the
transcript reads like a conversation. Adapted from the Firstmate project's
Calm implementation (MIT, Copyright Kun Chen - see its own LICENSE). Its
behavior is pinned by `tests/pi-calm.test.sh`.

## Notable decisions

- **Pi settings.json** - chezmoi's `modify_settings.json` merges a handful of
  managed defaults (theme, hideThinkingBlock, steeringMode, followUpMode) into
  the existing file on every apply, so fields pi writes at runtime survive.
- **herdr config.toml** - herdr rewrites this file at runtime, so it is
  templated by chezmoi with a documented tradeoff: edit
  `dot_config/herdr/config.toml.tmpl` and run `chezmoi apply`;
  don't rely on herdr's own settings UI to persist.
- **wezterm** - `~/.config/wezterm` is this repo's own `dot_config/wezterm/`
  tree (chezmoi-managed on the laptop, downloaded by `setup-windows.ps1` on
  Windows) - not a clone of an external framework. `dot_config/wezterm/utils/`
  and `dot_config/wezterm/events/` vendor the still-useful parts of the
  `KevinSilvester/wezterm-config` framework this config started from
  (MIT-licensed, attribution headers in each file).
- **lazygit state** - `state.yml` is runtime state and stays gitignored.

## Per-machine values (`~/.config/dotfiles/env`)

Machine-specific personal values (usernames, hostnames, LAN endpoints) are not
hardcoded in this repo - each machine supplies them in a plain `KEY=value`
file, `~/.config/dotfiles/env`:

```sh
cp env.example ~/.config/dotfiles/env
# then edit ~/.config/dotfiles/env - every key is documented in env.example
```

(or let the sibling `nix-config` repo's `setup.sh` generate it for you - it
prompts for only the keys the detected role needs, with existing values as
the defaults)

The file is gitignored and never committed; the committed `env.example` at the
repo root documents every key with a placeholder value. Keep secrets out of it
- it is plaintext, and credentials stay in `pass`/the OS secret store per the
"Keys and credentials" posture below.

How each consumer reads it:

- **Nix builds** - handled by the sibling `nix-config` repo, whose `setup.sh`
  writes the file for you: it asks only the keys of the detected role's
  matrix (every role gets `DOTFILES_USERNAME` + `DOTFILES_USER_EMAIL` +
  `DOTFILES_HOST_ROLE`, fixed to the role; laptop additionally gets
  `DOTFILES_SERVER_HOST`, `DOTFILES_SERVER_USER`, the three `JOY_CONSOLE_*`
  keys and `STEREO_TRANSCODE_ENDPOINT`) and drops any existing key outside
  that matrix on rewrite - the file is deterministic per role, and the script
  says so in its final summary. `WEZTERM_*` keys are never written here: they
  are Windows-side only, and the Windows machine keeps its own env file (see
  "Windows wezterm" under Bootstrap below for the one-click writer).
- **chezmoi** - `.chezmoi.toml.tmpl` parses the file into template
  data at `chezmoi apply` time.
- **wezterm** - `dot_config/wezterm/config/env.lua` parses the file at runtime.
- **fish** - `dot_config/fish/conf.d/dotfiles-env.fish` exports the values.

## Bootstrap

The Nix flake that drives the laptop, server, and wsl hosts now lives in the
sibling `nix-config` repo, not here - see its own `setup.sh` and README for
the guided installer and the manual per-host equivalents. As the last step
of its bootstrap, `nix-config/setup.sh` applies this repo's chezmoi-managed
dotfiles against `~/.dotfiles` (`chezmoi --source ~/.dotfiles init && apply`).

### Windows wezterm (`wezterm/setup-windows.ps1`)

Windows machines don't run this repo's nix flake - they only consume its
wezterm config. `wezterm/setup-windows.ps1` does the whole setup in one
run; it needs nothing beyond PowerShell 5.1+ (no git - it only downloads
files over HTTPS; the script is ASCII-only and `-WhatIf`-aware):

```powershell
# one-liner - fetch the script from the public mirror and run it
# (works from any PowerShell window, even with a strict execution policy):
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/babbarc/dotfiles/master/wezterm/setup-windows.ps1 -UseBasicParsing -o $env:TEMP\wezterm-setup.ps1; & $env:TEMP\wezterm-setup.ps1"
```

(or clone this repo and run `.\wezterm\setup-windows.ps1` from the checkout - a locally-run script is allowed under the default RemoteSigned policy)

The script is idempotent and does three things:

1. **Migration** - if an earlier version of this script left a
   `KevinSilvester/wezterm-config` clone behind (this config no longer uses
   that framework), removes its leftover `.git`, `backdrops/`, `colors/`,
   and the two `utils/backdrops.lua` / `utils/gpu-adapter.lua` files this
   config dropped. A no-op on a machine that never ran the old script.
2. **Config** - downloads this repo's complete `dot_config/wezterm/` tree
   (19 files: `wezterm.lua` plus everything under `config/`, `utils/`,
   `events/`) as raw files from the public GitHub mirror into
   `%USERPROFILE%\.config\wezterm`, recreating the same directory structure.
3. **Env file** - prompts for the Windows values and writes
   `%USERPROFILE%\.config\dotfiles\env` with exactly the Windows-relevant
   keys: `WEZTERM_WSL_SYSTEM_USER` (the NixOS-WSL host user, for the single
   `wsl:nixos` WSL domain) and `WEZTERM_GIT_BASH_PATH`. Values from an
   existing env file become the prompt defaults; keys outside that set are
   dropped on rewrite (the same deterministic per-role writer `nix-config`'s
   `setup.sh` uses), so re-runs keep your values. The WSL user defaults to your Windows
   username, and Git Bash to its standard install path.

Restart wezterm after it finishes. Re-run the script any time to update -
it re-downloads every file above; pass `-WhatIf` for a dry-run that prints
every step without changing anything.

**Manual fallback** - the same steps, driven by hand:

1. Download every file listed in `$ConfigFiles` near the top of
   `wezterm/setup-windows.ps1` from the public mirror into the matching
   path under `%USERPROFILE%\.config\wezterm`, e.g.:
   ```powershell
   $dst = "$env:USERPROFILE\.config\wezterm"
   New-Item -ItemType Directory -Force "$dst\config","$dst\utils","$dst\events" | Out-Null
   foreach ($f in 'wezterm.lua','config/appearance.lua','config/bindings.lua','config/domains.lua','config/env.lua','config/fonts.lua','config/general.lua','config/init.lua','config/launch.lua','utils/cells.lua','utils/math.lua','utils/opts-validator.lua','utils/platform.lua','utils/str.lua','events/gui-startup.lua','events/left-status.lua','events/new-tab-button.lua','events/right-status.lua','events/tab-title.lua') {
     $out = Join-Path $dst ($f -replace '/','\')
     iwr "https://raw.githubusercontent.com/babbarc/dotfiles/master/dot_config/wezterm/$f" -UseBasicParsing -o $out
   }
   ```
2. Create the env file - copy the "wezterm (Windows / WSL)" block from
   `env.example` and fill in the 10 keys listed above (plain `KEY=VALUE`
   lines, `#` whole-line comments; `JOY_CONSOLE_*` and `STEREO_*` keys are
   not needed on Windows):
   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\dotfiles" | Out-Null
   notepad "$env:USERPROFILE\.config\dotfiles\env"
   ```
3. Restart wezterm.

### Keys and credentials

No host manages SSH keys, GPG keys, or anything else credential-shaped -
set those up per machine, outside this repo.

### After the switch

A few tools this repo configures are deliberately not Nix-packaged: their
config is nix-managed by the sibling `nix-config` repo, but the binary has no
nixpkgs entry and no binary cache. These install themselves automatically on
your first switch, via a guarded `home.activation` block per tool in
`nix-config` - here's what happens and why:

- **firstmate** - if `~/firstmate` doesn't already exist, it's cloned from
  [kunchenguid/firstmate](https://github.com/kunchenguid/firstmate), the same
  posture as `~/.dotfiles` itself. Once it exists, no switch ever touches it
  again - it holds your own in-progress firstmate work. Update it yourself
  via `git pull` or firstmate's own `/updatefirstmate` skill.
- **herdr** - if `herdr` isn't on `PATH`, its curl installer runs. It lands
  at `~/.local/bin/herdr` and self-updates afterward via `herdr update` /
  `herdr channel set`. Only `dot_config/herdr/config.toml` is chezmoi-managed
  - see Notable decisions above.
- **treehouse and no-mistakes** - if either isn't on `PATH`, its curl
  installer runs. Update with `treehouse update`; no-mistakes has no separate
  update command, so its installer is just re-run.
- **axi suite** (`gh-axi`, `chrome-devtools-axi`, `lavish-axi`, `tasks-axi`,
  `quota-axi`, `gnhf`) - if any of the six is missing, `npm install -g` runs
  for the whole suite. Update with
  `npm update -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf`.

Every block above only runs when its tool is missing, so a switch on an
already-bootstrapped machine stays a fast no-op instead of a network call
every time. Each is also `||`-guarded so a failed curl/git/npm (no network, a
flaky mirror) only prints a warning and lets the rest of the switch proceed -
none of these installs can fail a `home-manager switch` outright. If you see
a warning, just re-run the switch once you're back online.

**The one step that stays manual: `gh auth login`.** It's an interactive
OAuth device-code flow, so it can't be scripted into activation - the `gh`
binary itself is nix-installed, but you authenticate it yourself, whenever
you're ready:
```sh
gh auth login
```
The switch prints a one-line reminder (via `gh auth status`) if you aren't
authenticated yet, but never blocks or fails on it.

Pi's own third-party extensions/themes and npm/git packages are managed by
Pi's installer at runtime, not a bootstrap step here.

## Attribution

WezTerm styling (rose-pine-moon, dimmed unfocused windows), the Pi Calm
extension, the shared `AGENTS.md` pattern, and the herdr tmux-style key
bindings are adapted from
[kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles).
