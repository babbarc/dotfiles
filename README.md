# dotfiles

Personal Linux dotfiles, managed with Nix home-manager. One repo, one
`home-manager switch`, and a fresh machine ends up configured the same way
every time.

These are personal dotfiles, shared publicly so people can read them, learn
from them, and fork them freely.

## Fresh machine setup

For a fresh standalone Arch-style host (the `laptop` or `server` output), the
`nix/setup-server.sh` script drives the whole bootstrap in one shot - it enables
Nix flakes, pre-flights the repo for the pure-eval symlink trap, and builds and
activates the host's home-manager generation.

```sh
# 1. Install Nix (multi-user) and clone this repo to ~/.dotfiles
sh <(curl -L https://nixos.org/nix/install) --daemon
git clone <this-repo> ~/.dotfiles

# 2. Bootstrap - auto-detects the host from `hostname` (or pass it explicitly:
#    `... setup-server.sh server`). Needs sudo for the flakes toggle.
~/.dotfiles/nix/setup-server.sh

# 3. Authenticate gh - interactive OAuth, the one step that stays manual
gh auth login
```

Run `~/.dotfiles/nix/setup-server.sh --dry-run` first to preview the exact
commands without sudo or a build. See the host-specific sections under Bootstrap
below for the manual equivalent of each step.

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

One flake (`nix/flake.nix`) drives three hosts. Steps below go from a bare
freshly-installed OS to a working switch; re-run the final command in each
section any time to apply later changes.

**Breaking change for the existing laptop:** the Arch host's flake output was
renamed from `homeConfigurations.USERNAME` to `homeConfigurations.laptop` (and
its config moved to `nix/hosts/laptop/home.nix`), to make room for a second
Arch host below and keep naming role-based across all three hosts. If you
already have this repo checked out on the laptop, your switch command changes:
```sh
home-manager switch --flake ~/.dotfiles/nix#USERNAME   # old
home-manager switch --flake ~/.dotfiles/nix#laptop    # new
```

### Arch laptop (`homeConfigurations.laptop`)

Standalone home-manager on Arch Linux, which isn't NixOS.

1. Install Nix ([nixos.org/download](https://nixos.org/download)) and make
   sure flakes are enabled (`experimental-features = nix-command flakes` in
   `nix.conf`, if your installer doesn't already set it).
2. Clone this repo to `~/.dotfiles`.
3. `home-manager` isn't installed yet, so build and activate the flake output
   directly:
   ```sh
   nix build ~/.dotfiles/nix#homeConfigurations.laptop.activationPackage
   ./result/activate
   ```
   That puts `home-manager` on `PATH`. From then on:
   ```sh
   home-manager switch --flake ~/.dotfiles/nix#laptop
   ```

### Arch server (`homeConfigurations.server`)

Same standalone home-manager shape as the laptop, but only the portable
`nix/modules/dev` bucket - no desktop/GUI modules, since a server has no
display.

1. Install Nix and enable flakes, same as the laptop above.
2. Clone this repo to `~/.dotfiles`.
3. Build and activate:
   ```sh
   nix build ~/.dotfiles/nix#homeConfigurations.server.activationPackage
   ./result/activate
   ```
   From then on:
   ```sh
   home-manager switch --flake ~/.dotfiles/nix#server
   ```

### WSL host (`nixosConfigurations.wsl`)

A full NixOS-WSL system (NixOS itself as the WSL2 distro), with
home-manager wired in as a NixOS module.

1. Install [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) as the
   WSL2 distro on the Windows machine - see that project's own install docs.
2. Clone this repo to `~/.dotfiles` (same path as the Arch hosts).
3. Activate:
   ```sh
   sudo nixos-rebuild switch --flake ~/.dotfiles/nix#wsl
   ```

### Keys and credentials

Neither host manages SSH keys, GPG keys, or anything else credential-shaped -
set those up per machine, outside this repo.

### After the switch

A few tools this repo configures are deliberately not Nix-packaged: their
config is nix-managed, but the binary has no nixpkgs entry and no binary
cache. These install themselves automatically on your first switch, via a
guarded `home.activation` block per tool (`lib.hm.dag.entryAfter [
"writeBoundary" ]`, the same mechanism `nix/modules/dev/pi.nix` uses to merge
`settings.json`) - here's what happens and why:

- **firstmate** - if `~/firstmate` doesn't already exist, it's cloned from
  [kunchenguid/firstmate](https://github.com/kunchenguid/firstmate)
  (`nix/modules/dev/firstmate.nix`), the same posture as `~/.dotfiles`
  itself. Once it exists, no switch ever touches it again - it holds your own
  in-progress firstmate work. Update it yourself via `git pull` or
  firstmate's own `/updatefirstmate` skill.
- **herdr** - if `herdr` isn't on `PATH`, its curl installer runs
  (`nix/modules/dev/herdr.nix`). It lands at `~/.local/bin/herdr` and
  self-updates afterward via `herdr update` / `herdr channel set`. Only
  `herdr/config.toml` is nix-managed - see Notable decisions above.
- **treehouse and no-mistakes** - if either isn't on `PATH`, its curl
  installer runs (`nix/modules/dev/agent-cli-tools.nix`). Update with
  `treehouse update`; no-mistakes has no separate update command, so its
  installer is just re-run.
- **axi suite** (`gh-axi`, `chrome-devtools-axi`, `lavish-axi`, `tasks-axi`,
  `quota-axi`, `gnhf`) - if any of the six is missing, `npm install -g` runs
  for the whole suite. This needs a writable npm prefix, which
  `nix/modules/dev/npm-global.nix`'s `~/.npmrc` already provides by the time
  any activation block runs. Update with
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
