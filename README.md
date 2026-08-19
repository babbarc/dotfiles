# dotfiles

Personal Linux dotfiles, managed with Nix home-manager. One repo, one
`home-manager switch`, and a fresh machine ends up configured the same way
every time.

These are personal dotfiles, shared publicly so people can read them, learn
from them, and fork them freely.

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

```
nix/                  Nix home-manager flake and per-tool modules
pi/                   Pi agent files: AGENTS.md, theme, extensions (incl. Calm)
wezterm/              The 5 config files that diverge from the wezterm-config
                      framework clone at ~/.config/wezterm
herdr/                herdr config.toml (read-only in the store; edit here)
nvim/                 lazyvim setup
fish/                 shell config
lazygit/              lazygit config.yml
tmux.conf.local       tmux configuration
tests/                Behavior tests, incl. the Pi Calm suite
docs/                 Design specs and implementation plans
```

## Agent instructions

`pi/AGENTS.md` is the single source of truth for global agent behavior. It is
symlinked from `nix/modules/pi.nix` into `~/.pi/agent/AGENTS.md` (pi),
`~/.claude/CLAUDE.md` (Claude Code), and `~/.codex/AGENTS.md` (Codex). Edit the
one file; every agent picks it up on its next session.

The Pi Calm extension (`pi/extensions/calm`) is a conversation-presentation
toggle for pi: `/calm` hides collapsed thinking and tool-call shells so the
transcript reads like a conversation. Adapted from the Firstmate project's
Calm implementation (MIT, Copyright Kun Chen - see its own LICENSE). Its
behavior is pinned by `tests/pi-calm.test.sh`.

## Notable decisions

- **Pi settings.json** - `nix/modules/pi.nix` merges a handful of managed
  defaults (theme, hideThinkingBlock, steeringMode, followUpMode) into the
  existing file on every switch, so fields pi writes at runtime survive.
- **herdr config.toml** - herdr rewrites this file at runtime, so it is a
  read-only nix-store copy with a documented tradeoff: edit
  `herdr/config.toml` and run `home-manager switch` to apply; don't rely on
  herdr's own settings UI to persist.
- **wezterm** - `~/.config/wezterm` is an upstream framework clone; only the 5
  files under `wezterm/config/` are nix-managed. Don't commit in that clone.
- **lazygit state** - `state.yml` is runtime state and stays gitignored.

## Rebuild

```sh
home-manager switch --flake ~/.dotfiles
```

## Attribution

WezTerm styling (rose-pine-moon, dimmed unfocused windows), the Pi Calm
extension, the shared `AGENTS.md` pattern, and the herdr tmux-style key
bindings are adapted from
[kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles).
