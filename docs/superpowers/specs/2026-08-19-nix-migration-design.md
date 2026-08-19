# Nix Migration Design

Date: 2026-08-19

## Goal

Move user-space CLI/dev tooling and select dotfiles from pacman/yay to Nix,
managed via standalone `home-manager` running on top of the existing Arch
Linux install. Arch remains the base OS — this is not a NixOS migration.

## Scope boundary

**Stays on pacman/yay — never touched by this project:**
- Boot & kernel: `linux`, `linux-firmware`, `grub`, `efibootmgr`, `intel-ucode`,
  `sof-firmware`, `sbctl`, `lvm2`
- Session/compositor stack: `sway`, `swaybg`, `swayidle`, `swaylock`,
  `greetd`, `greetd-gtkgreet`, `xorg-xwayland`, `kwayland5`, `qt5-wayland`,
  `qt6-wayland`, `xdg-desktop-portal-*`
- Hardware/drivers/system daemons: `pipewire-*`, `pulseaudio-alsa`,
  `alsa-utils`, `intel-gpu-tools`, `intel-media-driver`, `vulkan-intel`,
  `bluez-*`, `iwd`, `tlp`, `tp-battery-mode`, `fprintd`, `fwupd`, `cups`,
  `apparmor`, `iptables`, `systemd-resolvconf`, `docker*`, `podman*`,
  `nordvpn-bin`
- AUR-only / nightly packages with no clean nixpkgs equivalent:
  `wezterm-nightly-bin` (package only — its config *is* migrated, see below),
  `heimdall-grimler-git`, `monero-gui`, `electrum-ltc`, and similar
- All GUI applications (Firefox, GIMP, Spotify, Thunar, etc.) — explicitly
  out of scope
- `waybar` and `sway` config content — desktop/Arch-specific, not portable,
  left in `~/.dotfiles` managed exactly as today
- `.zshrc`, `.zshfn`, `ohmyzsh` submodule, `.tmux` submodule,
  `tmux.conf.local`, `tmux.service` — unused leftovers (shell is fish, not
  zsh/tmux); left alone entirely, not moved, not deleted
- `python-pip` — ad-hoc `pip install` doesn't fit Nix's model well; stays
  pacman-managed even though other dev tooling moves

**Moves to Nix / home-manager:**
- CLI tools available in nixpkgs (see Phase 1 list below)
- Dev toolchains: `nodejs`, `npm`, `python` (interpreter, not `pip`),
  `jdk-openjdk`, `maven`, `cmake`, `rust-analyzer`, `luarocks`, `aws-cli`,
  `influx-cli`, `neovim` (package)
- Dotfile *content* for: `fish`, `wezterm` (config only — the `wezterm-nightly-bin`
  binary stays on pacman), `nvim`, `lazygit`, `herdr`, `pi`
- Packages for `herdr` (via its own flake, `github:herdrdev/herdr`) and `pi`
  (`pi-coding-agent`, already in nixpkgs)

## Repo layout

New directory `~/.dotfiles/nix/`, versioned in the existing `~/.dotfiles` git
repo (gitea remote), alongside sway/waybar/nvim configs:

```
~/.dotfiles/nix/
  flake.nix          # inputs: nixpkgs (unstable), home-manager, herdr
  flake.lock
  home.nix           # top-level, imports modules below
  modules/
    cli-tools.nix
    dev-toolchains.nix
    fish.nix
    wezterm.nix
    nvim.nix
    lazygit.nix
    herdr.nix
    pi.nix
```

One module per concern so each can be reviewed, changed, or rolled back
independently. Standalone home-manager (not the NixOS module), activated via:

```
nix run home-manager -- switch --flake ~/.dotfiles/nix#USERNAME
```

Single `homeConfigurations` entry for this machine — no multi-host
structure for now. If this setup is later replicated on another machine,
that's a follow-up project, not designed for speculatively here.

`nixpkgs.config.allowUnfree` is not needed (no GUI/unfree packages in
scope).

## Phased rollout

1. **Phase 1 — Bootstrap + CLI pilot.** Get the flake/home-manager loop
   working end-to-end with a small, safe set of standalone CLI tools:
   `ripgrep`, `fd`, `bat`, `fzf`, `starship`, `htop`, `bottom`, `ncdu`,
   `gdu`, `git`, `git-crypt`, `git-filter-repo`, `tree-sitter-cli`, `yq`,
   `screen`, `wget`, `aria2`, `unzip`, `unrar`, `7zip`, `lbzip2`, `yt-dlp`,
   `translate-shell`, `speedtest-cli`, `ssh-audit`, `qrencode`, `zbar`,
   `gnu-netcat`, `nerdfix`, `sysz`, `presenterm`, `fortune-mod`. Validates
   PATH precedence between Nix and pacman, and the generation/rollback
   workflow, before anything else depends on it.

2. **Phase 2 — Dev toolchains.** `nodejs`, `npm`, `python`, `jdk-openjdk`,
   `maven`, `cmake`, `rust-analyzer`, `luarocks`, `aws-cli`, `influx-cli`,
   `neovim` (package only — config comes in Phase 3).

3. **Phase 3 — Dotfiles + their packages.** `programs.fish` (config +
   fisher-equivalent plugins: `fzf.fish`, `autopair.fish`,
   `fish-abbreviation-tips`, `z`), wezterm config content, nvim config
   content (using the Phase 2 `neovim` package), lazygit config content,
   `herdr` package (flake input) + config content, `pi` package (nixpkgs)
   + config content. Credentials for `herdr`/`pi` are explicitly **not**
   part of this — see Secrets below.

4. **Phase 4 — Cleanup (later, deliberate).** Once a migrated tool has
   been used and trusted for a while, explicitly `pacman -R` the
   superseded pacman package. Never automatic, never bundled into an
   earlier phase — always a separate, conscious step per package.

## Dotfiles mechanism

home-manager fully owns dotfile *content* via `home.file` / `xdg.configFile`
— content is copied into the Nix store and home-manager manages the
resulting symlinks itself (not out-of-store symlinks to the live
`~/.dotfiles` tree).

Practical consequence: home-manager refuses to manage a path that's
already a symlink/file it doesn't own. `nvim` and `lazygit` are currently
symlinked into `~/.config` by the old `mv-dotfiles.sh` script, so Phase 3
includes a one-time cutover: remove the existing symlink before the first
`home-manager switch` that manages that path.

After migration, editing these configs means editing the source file
under `~/.dotfiles/nix/modules/...` and running `home-manager switch` —
this replaces the previous instant edit-and-go workflow for the migrated
apps (fish, wezterm, nvim, lazygit, herdr, pi). Everything left on
`~/.dotfiles` proper (waybar, sway, unused zsh/tmux leftovers) keeps
working exactly as it does today, untouched.

## Secrets / per-machine credentials

`herdr` and `pi` both need API keys/auth that differ per machine. Per
decision, secrets are kept **out of Nix entirely**: home-manager only
installs and configures the tools themselves (non-secret config, e.g.
`herdr`'s `config.toml` theme/behavior settings). Actual credentials live
in local files outside the flake (e.g. `~/.config/pi/auth`,
`~/.config/herdr/*` auth-bearing files), set up manually per machine, and
are never committed to the `~/.dotfiles` git repo. No sops-nix/agenix or
other Nix secrets tooling is introduced.

## Safety / rollback

Every `home-manager switch` creates a new generation;
`home-manager switch --rollback` reverts instantly. Because pacman-installed
binaries of the same name are not removed until Phase 4, both versions
coexist on disk — if a Nix-provided tool misbehaves, removing it from
`home.packages`/the relevant module and switching falls straight back to
the pacman version already on `PATH`. No phase deletes or disables a
pacman package as part of migrating it; removal is always the separate,
explicit Phase 4 step, done per-package once trust is established.
