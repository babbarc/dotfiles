# dotfiles

Personal Linux dotfiles, managed with Nix home-manager. One repo, one
`home-manager switch`, and a fresh machine ends up configured the same way
every time.

These are personal dotfiles, shared publicly so people can read them, learn
from them, and fork them freely.

## Fresh machine setup

For any fresh host (the `laptop`, `server`, or `wsl` output), the single
`nix/setup.sh` script drives the whole bootstrap in one guided interactive run.
It detects the host role (distro NixOS -> wsl, hostname `laptop` -> laptop,
otherwise it asks; `--role` / `SETUP_ROLE` override), asks where to fetch the
repo from (your own Gitea server / the public GitHub mirror / an existing
checkout), prompts for only that role's per-machine env values, writes
`~/.config/dotfiles/env`, and builds + activates the right host:

- **laptop / server** - `homeConfigurations.<role>.activationPackage`, then
  `env HOME_MANAGER_BACKUP_EXT=backup ./result/activate`
- **wsl on NixOS** - `nixosConfigurations.wsl` system toplevel, then
  `sudo ./result/bin/switch-to-configuration switch`
- **wsl on any other distro** - the portable `homeConfigurations.server` dev
  profile, then `env HOME_MANAGER_BACKUP_EXT=backup ./result/activate`

```sh
# 1. Install Nix (multi-user). On NixOS-WSL it is preinstalled.
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Fetch the installer from the public GitHub mirror (or copy
#    nix/setup.sh out of any checkout), then run it.
curl -fsSL -o setup.sh \
  https://raw.githubusercontent.com/babbarc/dotfiles/master/nix/setup.sh
bash setup.sh

# 3. Authenticate gh - interactive OAuth, the one step that stays manual
gh auth login
```

`--dry-run` prints every command it would run without changing anything.
Re-run `~/.dotfiles/nix/setup.sh` anytime - it re-detects the role and reuses
the existing repo and env values. See the host-specific sections under Bootstrap
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
wezterm/              The 6 config files that diverge from the wezterm-config
                      framework clone at ~/.config/wezterm
herdr/                herdr config.toml (read-only in the store; edit here)
nvim/                 lazyvim setup
fish/                 shell config
lazygit/              lazygit config.yml
tmux.conf.local       tmux configuration
tests/                Behavior tests, incl. the Pi Calm suite
env.example           Template for the per-machine env file (see below)
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

## Per-machine values (`~/.config/dotfiles/env`)

Machine-specific personal values (usernames, hostnames, LAN endpoints) are not
hardcoded in this repo - each machine supplies them in a plain `KEY=value`
file, `~/.config/dotfiles/env`:

```sh
cp env.example ~/.config/dotfiles/env
# then edit ~/.config/dotfiles/env - every key is documented in env.example
```

(or let `nix/setup.sh` generate it for you - it prompts for only the keys the
detected role needs, with existing values as the defaults)

The file is gitignored and never committed; the committed `env.example` at the
repo root documents every key with a placeholder value. Keep secrets out of it
- it is plaintext, and credentials stay in `pass`/the OS secret store per the
"Keys and credentials" posture below.

How each consumer reads it:

- **Nix builds** - the flake input `dotfiles-env` defaults to the committed
  `env.example` and is overridden per machine, so pure evaluation never reads
  the file directly:
  ```sh
  nix build path:$HOME/.dotfiles?dir=nix#homeConfigurations.laptop.activationPackage \
    --override-input dotfiles-env path:$HOME/.config/dotfiles/env
  ```
  `nix/setup.sh` writes the file for you: it asks only the keys of the
  detected role's matrix (every role gets `DOTFILES_USERNAME` +
  `DOTFILES_HOST_ROLE`, fixed to the role; laptop additionally gets
  `DOTFILES_SERVER_HOST`, `DOTFILES_SERVER_USER`, the three `JOY_CONSOLE_*`
  keys and `STEREO_TRANSCODE_ENDPOINT`) and drops any existing key outside
  that matrix on rewrite - the file is deterministic per role, and the script
  says so in its final summary. `WEZTERM_*` keys are never written here: they
  are Windows-side only, and the Windows machine keeps its own env file.
- **wezterm** - `wezterm/config/env.lua` parses the file at runtime.
- **fish** - `fish/conf.d/dotfiles-env.fish` exports the values.
- **zsh** - `.zshrc` sources the file.

## Bootstrap

One flake (`nix/flake.nix`) drives three hosts. Every host can be
bootstrapped with the same guided installer (`nix/setup.sh` - see Fresh
machine setup); the sections below are the manual equivalent for each host
plus the exact switch commands. Steps below go from a bare freshly-installed
OS to a working switch; re-run the final command in each section any time to
apply later changes.

Host outputs are role-based (`laptop`, `server`, `wsl`), never username-based,
so switch commands don't embed any personal identifier. Every switch command
passes `--override-input dotfiles-env path:$HOME/.config/dotfiles/env` - that
is how the flake reads your per-machine `~/.config/dotfiles/env` instead of
the committed `env.example` (pure evaluation can't read the file directly;
see "Per-machine values" above). Omitting it silently builds with the
placeholder values from `env.example`.

> **Flake ref form.** Local filesystem refs use the repo-ROOT form with the
> `path:` scheme and `?dir=nix` (e.g. `path:$HOME/.dotfiles?dir=nix#laptop`),
> never a bare path into `nix/` (`~/.dotfiles/nix#laptop`). Nix ignores
> `?dir=nix` on a scheme-less path, so local refs MUST start with `path:`;
> remote URLs (`http://` tarballs, `git+http`, `https` GitHub) are fine as-is.
> Use `$HOME` (not `~`) inside `path:` URLs - neither the shell nor nix
> expands a `~` that isn't at the start of a word. Modules under
> `nix/modules/dev/` reference repo-root files (like `nvim/` and `fish/`) via
> `../../../`-style relative paths, so the flake source must be the whole repo.
> A bare `nix/` path ref makes nix treat the `nix/` directory as the source;
> those relative paths then escape to `/nix/store` and pure evaluation fails.
```sh
home-manager switch --flake path:$HOME/.dotfiles?dir=nix#laptop \
  --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
```

### Arch laptop (`homeConfigurations.laptop`)

Standalone home-manager on Arch Linux, which isn't NixOS. `nix/setup.sh`
detects this role from `hostname` (or pass `--role laptop`). Manual
equivalent:

1. Install Nix ([nixos.org/download](https://nixos.org/download)) and make
   sure flakes are enabled (`experimental-features = nix-command flakes` in
   `nix.conf`, if your installer doesn't already set it).
2. Clone this repo to `~/.dotfiles`.
3. `home-manager` isn't installed yet, so build and activate the flake output
   directly:
   ```sh
   nix build path:$HOME/.dotfiles?dir=nix#homeConfigurations.laptop.activationPackage
   ./result/activate
   ```
   That puts `home-manager` on `PATH`. From then on:
   ```sh
   home-manager switch --flake path:$HOME/.dotfiles?dir=nix#laptop \
     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
   ```

### Arch server (`homeConfigurations.server`)

Same standalone home-manager shape as the laptop, but only the portable
`nix/modules/dev` bucket - no desktop/GUI modules, since a server has no
display. `nix/setup.sh` prompts for this role (or pass `--role server`).
Manual equivalent:

1. Install Nix and enable flakes, same as the laptop above.
2. Clone this repo to `~/.dotfiles`.
3. Build and activate:
   ```sh
   nix build path:$HOME/.dotfiles?dir=nix#homeConfigurations.server.activationPackage
   ./result/activate
   ```
   From then on:
   ```sh
   home-manager switch --flake path:$HOME/.dotfiles?dir=nix#server \
     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
   ```

### WSL host (`nixosConfigurations.wsl`)

A full NixOS-WSL system (NixOS itself as the WSL2 distro), with
home-manager wired in as a NixOS module. The installer also works on any
other WSL distro (Ubuntu etc.): there it builds the same portable
`homeConfigurations.server` dev profile instead of a full system.

`nix/setup.sh` is the guided installer here too - on NixOS-WSL it builds the
full system (`nixosConfigurations.wsl`, `sudo ./result/bin/switch-to-configuration
switch`), on any other WSL distro the portable dev profile
(`homeConfigurations.server`). See Fresh machine setup for the one-liner;
`--dry-run` prints every command it would run without changing anything, and
re-running `~/.dotfiles/nix/setup.sh` anytime reuses the existing repo and
env values.

**Manual fallback** (the same commands the script runs internally, driven by
hand - still nix-only):

1. Install the distro: for the full system use
   [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) (see that
   project's own install docs; nix is preinstalled). For the dev-only
   profile, any distro with [nix](https://nixos.org/download) works.
2. Enable flakes for the session - never edit `/etc/nix/nix.conf` on NixOS,
   it is generated/read-only:
   ```sh
   export NIX_CONFIG="experimental-features = nix-command flakes"
   ```
3. Fetch the repo to `~/.dotfiles` (nix fetches it itself - the script
   prompts for your Gitea repo URL, shaped like the example below):
   ```sh
   GITEA="http://gitea.example.com:3222/user/dotfiles"   # your home Gitea
   STORE="$(nix-prefetch-url --unpack --print-path \
     "$GITEA/archive/master.tar.gz" | tail -n 1)"
   cp -a "$STORE" "$HOME/.dotfiles" && chmod -R u+w "$HOME/.dotfiles"
   ```
   (or `git clone https://github.com/babbarc/dotfiles.git ~/.dotfiles` for
   the public GitHub mirror, or `cp`/symlink an existing checkout).
4. Create the per-machine env file: `cp env.example ~/.config/dotfiles/env`
   and edit it (see "Per-machine values" above).
5. Build and activate. On NixOS-WSL (full system):
   ```sh
   nix build \
     "$GITEA/archive/master.tar.gz?dir=nix#nixosConfigurations.wsl.config.system.build.toplevel" \
     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
   sudo ./result/bin/switch-to-configuration switch
   ```
   On any non-NixOS distro, build `homeConfigurations.server.activationPackage`
   from the same URL (`?dir=nix#homeConfigurations.server.activationPackage`)
   with the same override, then `HOME_MANAGER_BACKUP_EXT=backup ./result/activate`.
6. Update later:
   ```sh
   sudo nixos-rebuild switch --flake path:$HOME/.dotfiles?dir=nix#wsl \
     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
   # non-NixOS WSL instead:
   #   home-manager switch --flake path:$HOME/.dotfiles?dir=nix#server \
   #     --override-input dotfiles-env "path:$HOME/.config/dotfiles/env"
   ```

### Keys and credentials

No host manages SSH keys, GPG keys, or anything else credential-shaped -
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
