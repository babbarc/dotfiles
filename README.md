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

## Bootstrap

One flake (`nix/flake.nix`) drives two hosts. Steps below go from a bare
freshly-installed OS to a working switch; re-run the final command in each
section any time to apply later changes.

### Arch host (`homeConfigurations.USERNAME`)

Standalone home-manager on Arch Linux, which isn't NixOS.

1. Install Nix ([nixos.org/download](https://nixos.org/download)) and make
   sure flakes are enabled (`experimental-features = nix-command flakes` in
   `nix.conf`, if your installer doesn't already set it).
2. Clone this repo to `~/.dotfiles`.
3. `home-manager` isn't installed yet, so build and activate the flake output
   directly:
   ```sh
   nix build ~/.dotfiles/nix#homeConfigurations.USERNAME.activationPackage
   ./result/activate
   ```
   That puts `home-manager` on `PATH`. From then on:
   ```sh
   home-manager switch --flake ~/.dotfiles/nix#USERNAME
   ```

### WSL host (`nixosConfigurations.wsl`)

A full NixOS-WSL system (NixOS itself as the WSL2 distro), with
home-manager wired in as a NixOS module.

1. Install [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) as the
   WSL2 distro on the Windows machine - see that project's own install docs.
2. Clone this repo to `~/.dotfiles` (same path as the Arch host).
3. Activate:
   ```sh
   sudo nixos-rebuild switch --flake ~/.dotfiles/nix#wsl
   ```

### Keys and credentials

Neither host manages SSH keys, GPG keys, or anything else credential-shaped -
set those up per machine, outside this repo.

### After the switch

A few tools this repo configures are deliberately not Nix-packaged: their
config is nix-managed, but the binary is installed and updated outside Nix.
Run these once per machine, after the switch above.

- **firstmate** - `~/firstmate` is a plain git clone
  ([kunchenguid/firstmate](https://github.com/kunchenguid/firstmate)), the
  same posture as `~/.dotfiles` itself (`nix/modules/dev/firstmate.nix`).
  Clone it, then update it later via `git pull` or firstmate's own
  `/updatefirstmate` skill. It also needs GitHub auth for PR creation - the
  `gh` binary is nix-installed, but the login step isn't:
  ```sh
  gh auth login
  ```
- **herdr** - installed via its own curl installer, not nixpkgs
  (`nix/modules/dev/herdr.nix`):
  ```sh
  curl -fsSL https://herdr.dev/install.sh | sh
  ```
  It lands at `~/.local/bin/herdr` and self-updates via `herdr update` /
  `herdr channel set`. Only `herdr/config.toml` is nix-managed - see Notable
  decisions above.
- **treehouse, no-mistakes, and the axi suite** (`gh-axi`,
  `chrome-devtools-axi`, `lavish-axi`, `tasks-axi`, `quota-axi`, `gnhf`) -
  none are in nixpkgs (`nix/modules/dev/agent-cli-tools.nix`). The switch
  above already fixes the npm global prefix
  (`nix/modules/dev/npm-global.nix`), which these installs need, so just run:
  ```sh
  curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
  npm install -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf
  ```
  Update the same way: `treehouse update`; re-run the no-mistakes install
  script (it has no separate update command); and
  `npm update -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf`.

Pi's own third-party extensions/themes and npm/git packages are managed by
Pi's installer at runtime, not a manual step here.

## Attribution

WezTerm styling (rose-pine-moon, dimmed unfocused windows), the Pi Calm
extension, the shared `AGENTS.md` pattern, and the herdr tmux-style key
bindings are adapted from
[kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles).
