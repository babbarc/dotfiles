# Nix/home-manager Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move user-space CLI/dev tooling and select dotfiles (fish, wezterm overrides, nvim, lazygit, pi) from pacman/yay to Nix, managed by standalone `home-manager` on top of the existing Arch install, in four phases with verified rollback at each step. herdr was descoped mid-execution (see Task 9) — it requires a from-source build with no binary cache, which conflicts with a "cache-fetched packages only" constraint set for this phase; it stays outside Nix entirely.

**Architecture:** A new flake at `~/.dotfiles/nix/` (versioned in the existing `~/.dotfiles` git repo) defines one `homeConfigurations."USERNAME"` built from `home.nix`, which imports one module per concern under `nix/modules/`. Dotfile content is fully owned by home-manager (copied into the Nix store, not out-of-store symlinks) except for files a program writes back to at runtime (`fish_variables`, lazygit's `state.yml`, nvim's `lazy-lock.json`), which are deliberately left unmanaged so they stay writable.

**Tech Stack:** Nix flakes, standalone home-manager (`nix-community/home-manager`), nixpkgs unstable. No custom flake inputs — the originally-planned `github:herdrdev/herdr` input was added in Task 1 and removed in Task 9 once herdr was descoped (it can't be cache-fetched).

---

## Reference: verified nixpkgs attribute names

These were confirmed against nixpkgs unstable via `nix search`/`nix eval` before writing this plan — use them exactly as given, don't substitute guesses:

| Tool | nixpkgs attribute | Note |
|---|---|---|
| ripgrep, fd, bat, fzf, starship, htop, bottom, ncdu, gdu, git, git-crypt, screen, wget, aria2, unzip, unrar, lbzip2, yt-dlp | same name | standard top-level attrs |
| git-filter-repo | `git-filter-repo` | |
| tree-sitter CLI | `tree-sitter` | not `tree-sitter-cli` |
| yq (mikefarah/yq, Go — matches pacman's `yq 4.1.2`) | `yq-go` | plain `yq` in nixpkgs is the unrelated Python/kislyuk wrapper (v3.x) |
| 7-Zip | `p7zip` | not `7zip` |
| gnu-netcat | `netcat-gnu` | |
| fortune-mod | `fortune` | attribute is `fortune`, pname is `fortune-mod` |
| nerdfix, sysz, presenterm, translate-shell, ssh-audit, qrencode, zbar, speedtest-cli | same name | |
| aws-cli (v1, matches pacman's `aws-cli 1.44.x`) | `awscli` | `awscli2` is the unwanted v2 |
| influx-cli | `influxdb2-cli` | pname is `influx-cli`, attribute is `influxdb2-cli` |
| luarocks | `luarocks` | resolves via default Lua version |
| rust-analyzer, cmake, maven | same name | |
| nodejs (matches pacman's `nodejs 26.x`) | `nodejs_26` | plain `nodejs`/`nodejs_latest` currently resolves to 24.19.0, not 26 |
| python interpreter | `python3` | |
| jdk | `jdk` | resolves to OpenJDK 21 in nixpkgs unstable at time of writing — older than pacman's `jdk-openjdk 26`; acceptable per spec (no nixpkgs 26 available) |
| pi coding agent | `pi-coding-agent` | binary name is `pi`; verified cache-fetched (`nix build --dry-run`), no source build |
| herdr | not in nixpkgs, no binary cache — would require a from-source build via its own flake (`github:herdrdev/herdr`). **Descoped in Task 9**; stays outside Nix entirely, not installed by this plan. |

All `nix search`/`nix eval` commands below assume flakes + `nix-command` are enabled, which they already are (`experimental-features = fetch-tree flakes nix-command` confirmed in this session).

---

### Task 1: Scaffold the flake and home.nix

**Files:**
- Create: `~/.dotfiles/nix/flake.nix`
- Create: `~/.dotfiles/nix/home.nix`

- [x] **Step 1: Create the directory**

Run: `mkdir -p ~/.dotfiles/nix/modules`

- [x] **Step 2: Write flake.nix**

```nix
{
  description = "USERNAME's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr.url = "github:herdrdev/herdr";
  };

  outputs = { self, nixpkgs, home-manager, herdr, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      homeConfigurations."USERNAME" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit herdr system; };
        modules = [ ./home.nix ];
      };
    };
}
```

- [x] **Step 3: Write home.nix**

`programs.fish.enable = true` is turned on here in bootstrap (not deferred to the fish
dotfiles phase) because fish is the interactive shell on this machine and home-manager's
fish integration is what generates the PATH-setup shim (`conf.d/hm-session-vars.fish`)
that later tasks' verification steps depend on. Its *content* (functions, frozen
theme/keybindings, fisher plugins) is added in Task 6.

```nix
{ config, pkgs, ... }:
{
  home.username = "USERNAME";
  home.homeDirectory = "/home/USERNAME";

  # Pin to the home-manager release this config was first created against.
  # Do not bump this when nixpkgs/home-manager update later — see home-manager's
  # documentation on stateVersion for why.
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
  programs.fish.enable = true;

  imports = [
    ./modules/cli-tools.nix
  ];
}
```

- [x] **Step 4: Verify the flake evaluates**

Run: `nix flake show ~/.dotfiles/nix`
Expected: lists `homeConfigurations.USERNAME` with no errors. (This will fail until
`modules/cli-tools.nix` exists — created in Task 3. If you want to verify Steps 1-3
in isolation first, temporarily comment out the `imports` line, run the check, then
restore it before Task 3.)

- [x] **Step 5: Commit**

```bash
cd ~/.dotfiles && git add nix/flake.nix nix/home.nix && git commit -m "nix: scaffold flake and home-manager entrypoint"
```

---

### Task 2: Create the Phase 1 CLI tools module and activate for the first time

**Files:**
- Create: `~/.dotfiles/nix/modules/cli-tools.nix`

- [x] **Step 1: Write the module**

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    fzf
    starship
    htop
    bottom
    ncdu
    gdu
    git
    git-crypt
    git-filter-repo
    tree-sitter
    yq-go
    screen
    wget
    aria2
    unzip
    unrar
    p7zip
    lbzip2
    yt-dlp
    translate-shell
    speedtest-cli
    ssh-audit
    qrencode
    zbar
    netcat-gnu
    nerdfix
    sysz
    presenterm
    fortune
  ];
}
```

- [x] **Step 2: First activation**

home-manager isn't installed as a command yet, so the first switch is bootstrapped
via `nix run` against the well-known `home-manager` flake registry entry. Every switch
in this plan uses `-b backup`, which renames any pre-existing file home-manager would
otherwise conflict with to `<file>.backup` instead of erroring — this is what safely
handles first-time adoption of paths (like `~/.config/fish/config.fish` later) that
already have plain, unmanaged content on disk.

Run: `nix run home-manager -- switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: build succeeds, ends with `Creating home-manager generation` and no errors.

- [x] **Step 3: Verify the generation was created**

Run: `home-manager generations`
Expected: exactly one line, timestamped today.

- [x] **Step 4: Pick up the new PATH in an interactive shell**

The running shell (this one) won't see the new `~/.nix-profile/bin` entries or fish's
new `conf.d/hm-session-vars.fish` until a new shell starts.

Run: `exec fish -c 'which rg; which fd; which bat; which fzf; which starship; which htop'`
Expected: every path printed contains `/nix/store/` or `/home/USERNAME/.nix-profile/`
(not `/usr/bin/`).

- [x] **Step 5: Sanity-check a couple of tools actually run**

Run: `exec fish -c 'rg --version; starship --version'`
Expected: both print version output without error.

- [x] **Step 6: Commit**

```bash
cd ~/.dotfiles && git add nix/modules/cli-tools.nix && git commit -m "nix(cli-tools): migrate phase 1 CLI toolset to home-manager"
```

---

### Task 3: Verify PATH precedence and generation rollback

This task exists because the spec calls out PATH precedence and rollback as things
that must be validated before building anything else on top of the bootstrap. `rg`
(ripgrep) is the test subject because it's installed both via pacman (`ripgrep
15.2.0-1`, confirmed in `pacman -Qe`) and now via Nix — a real coexistence case, not
a hypothetical.

**Files:** none (verification only)

- [x] **Step 1: Confirm both versions exist on disk**

Run: `pacman -Q ripgrep && ls -la /nix/var/nix/profiles/per-user/USERNAME/home-manager/home-path/bin/rg 2>/dev/null || readlink -f $(fish -c 'which rg')`
Expected: pacman shows `ripgrep 15.2.0-1` installed; the Nix-provided `rg` resolves to
a path under `/nix/store/`.

- [x] **Step 2: Roll back one generation and confirm PATH falls back to pacman**

```bash
home-manager generations
home-manager switch --rollback
exec fish -c 'which rg'
```
Expected: after rollback, `which rg` in the new shell resolves to `/usr/bin/rg`
(the pacman-installed binary) — proving that removing/rolling back the Nix version
doesn't break `rg` availability, it just falls through to pacman's copy still on
`PATH`.

- [x] **Step 3: Switch forward again to restore the Nix-managed generation**

```bash
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
exec fish -c 'which rg'
```
Expected: `which rg` now resolves to the `/nix/store/` path again.

- [x] **Step 4: No commit needed**

This task only exercises existing generations; there's no file change to commit.

---

### Task 4: Phase 2 — dev toolchains

**Files:**
- Create: `~/.dotfiles/nix/modules/dev-toolchains.nix`
- Modify: `~/.dotfiles/nix/home.nix:16-18` (imports list)

- [x] **Step 1: Write the module**

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs_26
    python3
    jdk
    maven
    cmake
    rust-analyzer
    luarocks
    awscli
    influxdb2-cli
    neovim
  ];
}
```

- [x] **Step 2: Add the import**

In `~/.dotfiles/nix/home.nix`, change:
```nix
  imports = [
    ./modules/cli-tools.nix
  ];
```
to:
```nix
  imports = [
    ./modules/cli-tools.nix
    ./modules/dev-toolchains.nix
  ];
```

- [x] **Step 3: Switch and verify**

```bash
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
exec fish -c 'which node; which npm; which python3; which mvn; which cmake; which rust-analyzer; which aws; which influx; which nvim'
```
Expected: all resolve under `/nix/store/` or `/home/USERNAME/.nix-profile/`. `npm`
comes bundled with the `nodejs_26` derivation — no separate package needed.

- [x] **Step 4: Confirm versions run**

Run: `exec fish -c 'node --version; npm --version; python3 --version; nvim --version | head -1'`
Expected: version strings print without error (Node should report a `v26.x` version).

- [x] **Step 5: Commit**

```bash
cd ~/.dotfiles && git add nix/home.nix nix/modules/dev-toolchains.nix && git commit -m "nix(dev-toolchains): migrate phase 2 dev toolchains to home-manager"
```

---

### Task 5: Phase 3a — fish (config content + fisher package)

`fish`'s package and PATH shim were already enabled in Task 1. This task migrates the
**user-authored** fish config files into `~/.dotfiles/fish` and manages them
individually — deliberately *not* claiming the whole `~/.config/fish` or
`~/.config/fish/conf.d` directory, for two reasons:

1. home-manager's fish module writes its own file into `conf.d/`
   (`hm-session-vars.fish`); claiming the whole `conf.d` directory as one recursive
   source would collide with that.
2. `fish_plugins`, `fish_variables`, and the fisher-installed plugin files
   (`conf.d/fzf.fish`, `conf.d/autopair.fish`, `conf.d/abbr_tips.fish`,
   `conf.d/z.fish`, and their corresponding `functions/_fzf_*`,
   `functions/_autopair_*`, `functions/__abbr_tips_*`, `functions/__z*.fish`,
   `completions/fzf_configure_bindings.fish`) stay owned by fisher exactly as today —
   they are **not** migrated to `programs.fish.plugins`. `fisher` itself moves to Nix
   (as a package) so the tool is Nix-managed even though its plugin data isn't.
   `fish_variables` is fish's own universal-variable state file — Nix-managing it
   would make it read-only and break `set -U`, so it's left alone.

**Files:**
- Create: `~/.dotfiles/fish/config.fish`
- Create: `~/.dotfiles/fish/conf.d/fish_frozen_theme.fish`
- Create: `~/.dotfiles/fish/conf.d/fish_frozen_key_bindings.fish`
- Create: `~/.dotfiles/fish/functions/fish_greeting.fish`
- Create: `~/.dotfiles/fish/functions/joy-console.fish`
- Create: `~/.dotfiles/fish/functions/rgf.fish`
- Create: `~/.dotfiles/fish/functions/s.fish`
- Create: `~/.dotfiles/fish/themes/` (directory copy)
- Create: `~/.dotfiles/nix/modules/fish.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Copy the user-authored files into the dotfiles repo**

```bash
mkdir -p ~/.dotfiles/fish/conf.d ~/.dotfiles/fish/functions
cp ~/.config/fish/config.fish ~/.dotfiles/fish/config.fish
cp ~/.config/fish/conf.d/fish_frozen_theme.fish ~/.dotfiles/fish/conf.d/
cp ~/.config/fish/conf.d/fish_frozen_key_bindings.fish ~/.dotfiles/fish/conf.d/
cp ~/.config/fish/functions/fish_greeting.fish ~/.dotfiles/fish/functions/
cp ~/.config/fish/functions/joy-console.fish ~/.dotfiles/fish/functions/
cp ~/.config/fish/functions/rgf.fish ~/.dotfiles/fish/functions/
cp ~/.config/fish/functions/s.fish ~/.dotfiles/fish/functions/
cp -r ~/.config/fish/themes ~/.dotfiles/fish/themes
```

- [x] **Step 2: Write the module**

**CORRECTED (post-implementation) — differs from the original draft below in
several load-bearing ways, discovered while implementing this task and, in one
case, while implementing Task 10:**
1. `pkgs.fisher` does not exist in nixpkgs — there is no `home.packages`/`fisher`
   entry. Fisher stays exactly as pacman-installed today (`fisher 4.4.8-1`); only
   fish's config *content* moves to Nix.
2. Paths are `../../fish/...`, not `../fish/...` — `nix/modules/fish.nix` is two
   directories below the repo root (`nix/modules/`), so reaching `~/.dotfiles/fish/`
   needs two `../`, not one. (This same off-by-one existed in the original drafts of
   Tasks 6-9 below and has been corrected there too.)
3. **`lib.mkForce` on `config.fish` was tried first, then reverted — it caused a
   real regression.** `programs.fish` (enabled since Task 1) already defines
   `xdg.configFile."fish/config.fish"` internally, so a plain second definition of
   that key is a "conflicting definition values" eval error. `lib.mkForce` resolves
   the eval error, but it does so by fully *replacing* home-manager's generated
   config.fish — which silently dropped the `hm-session-vars.fish` sourcing that
   adds `~/.nix-profile/bin` to PATH. The result: no Nix-installed package's binary
   was reachable by bare name in any fish shell, for as long as this was in place.
   This went undetected through Tasks 6-9 because their fish-based `which <tool>`
   checks all happened to hit a pacman-installed fallback of the same tool; it
   surfaced only in Task 10, on `pi` (the first Nix-only tool with no such
   fallback). **Fixed** by using `programs.fish.interactiveShellInit` instead,
   which lets home-manager keep generating config.fish (PATH setup included) while
   still injecting the user's two lines (starship init, greeting suppression) into
   it. `~/.dotfiles/fish/config.fish` was removed — its content now lives directly
   in `interactiveShellInit` below, since a standalone file no longer being read by
   anything would be a stale, misleading duplicate.

```nix
{ ... }:
{
  # programs.fish.enable is already set in home.nix (Task 1).
  # fisher itself stays pacman-managed (fisher 4.4.8-1) — it isn't packaged in
  # nixpkgs; only fish's config content is migrated here.

  programs.fish.interactiveShellInit = ''
    starship init fish | source
    set -g fish_greeting
  '';

  xdg.configFile = {
    "fish/conf.d/fish_frozen_theme.fish".source = ../../fish/conf.d/fish_frozen_theme.fish;
    "fish/conf.d/fish_frozen_key_bindings.fish".source = ../../fish/conf.d/fish_frozen_key_bindings.fish;
    "fish/functions/fish_greeting.fish".source = ../../fish/functions/fish_greeting.fish;
    "fish/functions/joy-console.fish".source = ../../fish/functions/joy-console.fish;
    "fish/functions/rgf.fish".source = ../../fish/functions/rgf.fish;
    "fish/functions/s.fish".source = ../../fish/functions/s.fish;
    "fish/themes" = {
      source = ../../fish/themes;
      recursive = true;
    };
  };
}
```

Note: the live `~/.config/fish/themes/` directory was empty, and git cannot track
empty directories, so a placeholder `~/.dotfiles/fish/themes/.gitkeep` was added so
the flake's git-tracked source can see the directory at all.

- [x] **Step 3: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/fish.nix` to the `imports` list.

- [x] **Step 4: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds. Any of the 7 files that already existed as plain files get
renamed to `<name>.backup` by the `-b backup` flag rather than causing an error.

- [x] **Step 5: Verify fish still starts correctly with fisher-managed plugins intact**

```bash
exec fish -c 'which fisher; fisher list; type joy-console; type rgf; type s'
```
Expected: `fisher` resolves under `/nix/store/`; `fisher list` still shows
`patrickf1/fzf.fish`, `jorgebucaran/autopair.fish`, `gazorby/fish-abbreviation-tips`,
`jethrokuan/z`; the three custom functions are found (no "not a function" errors).

- [x] **Step 6: Verify universal variables still work**

Run: `fish -c 'set -U __hm_migration_test 1; set -U -e __hm_migration_test'`
Expected: no permission/read-only errors — confirms `fish_variables` was correctly
left writable.

- [x] **Step 7: Diff the backups to confirm no content was lost, then remove them**

```bash
diff ~/.config/fish/config.fish.backup ~/.dotfiles/fish/config.fish
```
Expected: no output (files identical). Repeat for the other `.backup` files created
in Step 4, then `rm` each `.backup` file once confirmed.

- [x] **Step 8: Commit**

```bash
cd ~/.dotfiles && git add fish nix/home.nix nix/modules/fish.nix && git commit -m "nix(fish): migrate fish config content and fisher to home-manager"
```

---

### Task 6: Phase 3b — wezterm overrides

`~/.config/wezterm` is a full clone of the `KevinSilvester/wezterm-config` upstream
framework (its own `.git`, tracking `origin` = the upstream repo), not a simple
dotfile. Diffing local `HEAD` against `origin/master` shows exactly 5 files with real
customizations: `config/appearance.lua`, `config/bindings.lua`, `config/domains.lua`,
`config/fonts.lua`, `config/launch.lua`. Everything else in that directory (including
the `backdrops/` images, `utils/`, `events/`, `colors/custom.lua`, which matches
upstream exactly) stays untouched, still pulled via that repo's own `git pull`.

Because home-manager will symlink these 5 files in place inside an active git working
tree, they must first be untracked from that repo (kept on disk, just no longer
git-tracked there) so its `git status`/`git pull` don't see them as conflicting.

**Files:**
- Create: `~/.dotfiles/wezterm/config/appearance.lua`
- Create: `~/.dotfiles/wezterm/config/bindings.lua`
- Create: `~/.dotfiles/wezterm/config/domains.lua`
- Create: `~/.dotfiles/wezterm/config/fonts.lua`
- Create: `~/.dotfiles/wezterm/config/launch.lua`
- Create: `~/.dotfiles/nix/modules/wezterm.nix`
- Modify: `~/.config/wezterm/.git/info/exclude` (local-only untrack, via `git rm --cached`)
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Copy the 5 override files into the dotfiles repo**

```bash
mkdir -p ~/.dotfiles/wezterm/config
cp ~/.config/wezterm/config/appearance.lua ~/.dotfiles/wezterm/config/
cp ~/.config/wezterm/config/bindings.lua ~/.dotfiles/wezterm/config/
cp ~/.config/wezterm/config/domains.lua ~/.dotfiles/wezterm/config/
cp ~/.config/wezterm/config/fonts.lua ~/.dotfiles/wezterm/config/
cp ~/.config/wezterm/config/launch.lua ~/.dotfiles/wezterm/config/
```

- [x] **Step 2: Untrack the 5 files inside the wezterm-config clone**

```bash
cd ~/.config/wezterm
git rm --cached config/appearance.lua config/bindings.lua config/domains.lua config/fonts.lua config/launch.lua
printf '%s\n' config/appearance.lua config/bindings.lua config/domains.lua config/fonts.lua config/launch.lua >> .git/info/exclude
git status --short
```
Expected: `git status` shows nothing for these 5 paths (they're now ignored via
`.git/info/exclude`, which — unlike `.gitignore` — is local-only and never gets
overwritten by an upstream pull).

- [x] **Step 3: Write the module**

Paths are `../../wezterm/...`, not `../wezterm/...` — `nix/modules/wezterm.nix` is
two directories below the repo root, so reaching `~/.dotfiles/wezterm/` needs two
`../`. (This off-by-one was discovered and corrected during Task 5's implementation;
applying the fix here up front.)

```nix
{ ... }:
{
  xdg.configFile = {
    "wezterm/config/appearance.lua".source = ../../wezterm/config/appearance.lua;
    "wezterm/config/bindings.lua".source = ../../wezterm/config/bindings.lua;
    "wezterm/config/domains.lua".source = ../../wezterm/config/domains.lua;
    "wezterm/config/fonts.lua".source = ../../wezterm/config/fonts.lua;
    "wezterm/config/launch.lua".source = ../../wezterm/config/launch.lua;
  };
}
```

- [x] **Step 4: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/wezterm.nix` to the `imports` list.

- [x] **Step 5: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds; the 5 plain files get backed up to `.backup` and replaced with
symlinks into the Nix store.

- [x] **Step 6: Verify content and that wezterm's own git tree is clean**

```bash
diff ~/.config/wezterm/config/bindings.lua.backup ~/.dotfiles/wezterm/config/bindings.lua
git -C ~/.config/wezterm status --short
```
Expected: no diff output; `git status` in the wezterm clone shows clean (no untracked
or modified entries for the 5 files).

- [x] **Step 7: Validate the Lua is syntactically sound**

Run: `for f in ~/.dotfiles/wezterm/config/*.lua; do lua -e "assert(loadfile(\"$f\"))" && echo "OK: $f"; done`
Expected: `OK:` printed for all 5 files, no syntax errors. (If `lua` isn't on PATH,
skip this and instead run `wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts >/dev/null` or launch wezterm interactively to confirm it starts without a config error banner.)

- [x] **Step 8: Remove the confirmed backup files**

```bash
rm ~/.config/wezterm/config/*.backup
```

- [x] **Step 9: Commit**

```bash
cd ~/.dotfiles && git add wezterm nix/home.nix nix/modules/wezterm.nix && git commit -m "nix(wezterm): migrate wezterm config overrides to home-manager"
```

---

### Task 7: Phase 3c — nvim

nvim's config already lives in `~/.dotfiles/nvim`, currently reached via a plain
symlink from `~/.config/nvim` (created by the old `mv-dotfiles.sh`). This task
switches that to home-manager-managed symlinks, file by file, **excluding
`lazy-lock.json`** — lazy.nvim writes to that file on `:Lazy update`, and a
Nix-store-backed symlink would be read-only and break that. Instead, `lazy-lock.json`
keeps a plain, manually-created symlink back into `~/.dotfiles/nvim` (the same
mechanism the whole directory used before), so it stays both git-tracked and
writable.

**Files:**
- Create: `~/.dotfiles/nix/modules/nvim.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Remove the old whole-directory symlink**

```bash
rm ~/.config/nvim
```
(Safe: the target content lives in `~/.dotfiles/nvim`, unaffected by removing the
symlink that points to it.)

- [x] **Step 2: Write the module**

Paths are `../../nvim/...`, not `../nvim/...` — `nix/modules/nvim.nix` is two
directories below the repo root, so reaching `~/.dotfiles/nvim/` needs two `../`.

```nix
{ ... }:
{
  xdg.configFile = {
    "nvim/init.lua".source = ../../nvim/init.lua;
    "nvim/lazyvim.json".source = ../../nvim/lazyvim.json;
    "nvim/stylua.toml".source = ../../nvim/stylua.toml;
    "nvim/lua" = {
      source = ../../nvim/lua;
      recursive = true;
    };
    "nvim/snippets" = {
      source = ../../nvim/snippets;
      recursive = true;
    };
  };
}
```

- [x] **Step 3: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/nvim.nix` to the `imports` list.

- [x] **Step 4: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds; `~/.config/nvim` is recreated as a real directory containing
home-manager-owned symlinks for each managed path.

- [x] **Step 5: Manually restore the lazy-lock.json symlink**

```bash
ln -s ~/.dotfiles/nvim/lazy-lock.json ~/.config/nvim/lazy-lock.json
```

- [x] **Step 6: Verify nvim starts and plugins load**

Run: `exec fish -c 'nvim --headless "+Lazy! sync" +qa'`
Expected: exits without error output about missing plugins or a read-only
`lazy-lock.json`.

- [x] **Step 7: Commit**

```bash
cd ~/.dotfiles && git add nix/home.nix nix/modules/nvim.nix && git commit -m "nix(nvim): manage nvim config via home-manager"
```

---

### Task 8: Phase 3d — lazygit

Same pattern as nvim: `~/.config/lazygit` is currently a whole-directory symlink to
`~/.dotfiles/lazygit`, which contains both `config.yml` (user config) and `state.yml`
(lazygit's own runtime state — recent repos, command history — confirmed actively
written by checking its mtime). Only `config.yml` moves to home-manager management;
`state.yml` becomes a plain local file so lazygit can keep writing to it.

**Files:**
- Create: `~/.dotfiles/nix/modules/lazygit.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Remove the old whole-directory symlink, keep state.yml as a plain file**

```bash
cp ~/.dotfiles/lazygit/state.yml /tmp/lazygit-state.yml.bak
rm ~/.config/lazygit
mkdir -p ~/.config/lazygit
cp /tmp/lazygit-state.yml.bak ~/.config/lazygit/state.yml
```

- [x] **Step 2: Write the module**

Path is `../../lazygit/config.yml`, not `../lazygit/config.yml` — `nix/modules/lazygit.nix`
is two directories below the repo root.

```nix
{ ... }:
{
  xdg.configFile."lazygit/config.yml".source = ../../lazygit/config.yml;
}
```

- [x] **Step 3: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/lazygit.nix` to the `imports` list.

- [x] **Step 4: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds; `~/.config/lazygit/config.yml` becomes a symlink into the Nix
store, `~/.config/lazygit/state.yml` stays the plain file copied in Step 1.

- [x] **Step 5: Verify lazygit runs and can write state**

```bash
cd ~/.dotfiles && lazygit --version
fish -c 'cd ~/.dotfiles && timeout 2 lazygit >/dev/null 2>&1; true'
cat ~/.config/lazygit/state.yml | grep -A2 recentrepos
```
Expected: version prints; `state.yml` still contains (and can still be updated with)
the recent-repos list, confirming it's writable.

- [x] **Step 6: Commit**

```bash
cd ~/.dotfiles && git add nix/home.nix nix/modules/lazygit.nix && git commit -m "nix(lazygit): manage lazygit config.yml via home-manager"
```

---

### Task 9: Phase 3e — herdr — SKIPPED

**Decision (made mid-execution, overriding the original task below): herdr is
excluded from this migration entirely.** herdr is not in nixpkgs, has no binary
cache, and can only be obtained as a Nix package by compiling it from source via
its own flake (`github:herdrdev/herdr`, a Rust project) — confirmed via
`nix build --dry-run`, which showed no substitutable path, only a from-source build.
Per an explicit decision that this first migration phase should contain **no
packages that require building from source** (cache-fetched only), herdr stays
completely outside Nix: it remains exactly as it was before this migration, manually
installed via its own `curl -fsSL https://herdr.dev/install.sh | sh` installer at
`~/.local/bin/herdr`, with `~/.config/herdr/` untouched.

Cleanup performed as part of this decision:
- The unused `herdr` flake input was removed from `nix/flake.nix` (and
  `extraSpecialArgs`), and `nix/flake.lock` regenerated (`nix flake lock`) to drop
  its now-unreferenced transitive inputs (`herdr/nixpkgs`, `herdr/rust-overlay`,
  `herdr/rust-overlay/nixpkgs`).
- All other packages already in `cli-tools.nix` and `dev-toolchains.nix` were
  re-verified against this same "cache-fetched only" constraint (`nix build
  --dry-run` on each) — all confirmed substitutable, no source builds, no rework
  needed there.
- `pi-coding-agent` (Task 10, below) was also verified substitutable before
  proceeding — it fetches from nixpkgs' binary cache, no source build.

The original task text (never executed — a build was in progress when this decision
was made, and was aborted with no lasting effect: `~/.local/bin/herdr` was briefly
deleted mid-task and restored via the same official installer before any Nix
generation activated it) is left below for historical record only. Do not execute it.

<details>
<summary>Original Task 9 text (not executed, kept for reference)</summary>

herdr is already installed manually (via its curl installer) at `~/.local/bin/herdr`,
integrated with Codex CLI via `~/.codex/herdr-agent-state.sh`. This task replaces the
manually-installed binary with the one built from herdr's own flake, and brings
`config.toml` under home-manager — but only `config.toml`. The `~/.config/herdr`
directory also contains `herdr-client.log`, `herdr-server.log`, and `.plugins.lock`,
all of which are runtime-written and must stay out of Nix management. `config.toml`
was checked for embedded secrets (theme/keybinding settings only, no API keys or
tokens found) — per the spec, actual credentials for herdr stay local and unmanaged,
outside this repo entirely.

**Files:**
- Create: `~/.dotfiles/herdr/config.toml`
- Create: `~/.dotfiles/nix/modules/herdr.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Copy the config into the dotfiles repo**

```bash
mkdir -p ~/.dotfiles/herdr
cp ~/.config/herdr/config.toml ~/.dotfiles/herdr/config.toml
```

- [x] **Step 2: Double-check no secrets are in the file before committing it**

Run: `grep -inE "sk-|api[_-]?key\s*=|token\s*=\s*\"[A-Za-z0-9]|bearer" ~/.dotfiles/herdr/config.toml`
Expected: no output. If anything matches, stop and remove/redact that line before
proceeding — do not commit it.

- [x] **Step 3: Remove the manually curl-installed binary**

```bash
rm ~/.local/bin/herdr
```
(The Codex integration script at `~/.codex/herdr-agent-state.sh` calls `herdr` by
name via `$PATH`, not by absolute path, so it will pick up the Nix-provided binary
once it's on `PATH` — no change needed there.)

- [x] **Step 4: Write the module**

Path is `../../herdr/config.toml`, not `../herdr/config.toml` — `nix/modules/herdr.nix`
is two directories below the repo root.

```nix
{ pkgs, herdr, system, ... }:
{
  home.packages = [
    herdr.packages.${system}.default
  ];

  xdg.configFile."herdr/config.toml".source = ../../herdr/config.toml;
}
```

- [x] **Step 5: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/herdr.nix` to the `imports` list.

- [x] **Step 6: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds; builds herdr from its flake input.

- [x] **Step 7: Verify**

```bash
exec fish -c 'which herdr; herdr --version'
cat ~/.config/herdr/config.toml | head -3
ls ~/.config/herdr/
```
Expected: `herdr` resolves under `/nix/store/`; version prints; `config.toml` shows
the migrated content; `herdr-client.log`, `herdr-server.log`, `.plugins.lock` are
still present as plain files (untouched, still writable).

- [x] **Step 8: Commit**

```bash
cd ~/.dotfiles && git add herdr nix/home.nix nix/modules/herdr.nix && git commit -m "nix(herdr): migrate herdr to its own flake input, manage config.toml"
```

</details>

---

### Task 10: Phase 3f — pi

`pi` (the `pi-coding-agent` npm package, `@earendil-works/pi-coding-agent`) is not
currently installed on this machine, and is already packaged in nixpkgs directly —
no flake input needed. There's no existing config to migrate; per the spec,
credentials/auth for pi are set up manually per machine and never committed.

**Files:**
- Create: `~/.dotfiles/nix/modules/pi.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

- [x] **Step 1: Write the module**

```nix
{ pkgs, ... }:
{
  home.packages = [
    pkgs.pi-coding-agent
  ];
}
```

- [x] **Step 2: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/pi.nix` to the `imports` list.

- [x] **Step 3: Switch**

Run: `home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`
Expected: succeeds.

- [x] **Step 4: Verify**

Run: `exec fish -c 'which pi; pi --version'`
Expected: resolves under `/nix/store/`; version prints. (`pi` will prompt for
provider auth on first real use — that's expected; set it up manually per the
secrets policy, not as part of this task.)

**Post-implementation note:** this step is what surfaced a real, previously-unnoticed
regression from Task 5 — `fish/config.fish`'s `lib.mkForce` override had silently
dropped home-manager's `hm-session-vars.fish` sourcing, so `~/.nix-profile/bin` was
missing from fish's PATH entirely (not just losing an ordering contest). It went
unnoticed through Tasks 6-9 because every fish-based `which <tool>` check up to this
point happened to hit a pacman-installed fallback of the same tool; `pi` was the first
Nix-only tool with no such fallback. Separately, an unrelated pre-existing npm global
install of `pi` at `~/.local/bin/pi` (predating this migration, installed 2026-08-19
03:30) was also shadowing the intended binary. Both were fixed: `fish.nix` now uses
`programs.fish.interactiveShellInit` instead of overriding `config.fish` wholesale
(see Task 5's section, updated to match), and the stray npm install was removed
(`npm uninstall -g --prefix ~/.local @earendil-works/pi-coding-agent`). Verified live
afterward: `which pi` and `which rg` both correctly resolve under `/nix/store/` in a
fresh fish shell.

- [x] **Step 5: Commit**

```bash
cd ~/.dotfiles && git add nix/home.nix nix/modules/pi.nix && git commit -m "nix(pi): install pi coding agent via home-manager"
```

---

### Task 11: Final verification pass

**Files:** none (verification only)

- [x] **Step 1: Confirm the full generation history is intact and rollback still works**

```bash
home-manager generations
```
Expected: one generation per switch performed across Tasks 2, 4-10 (roughly 9-10
generations), each rollback-able independently via
`home-manager switch --switch-generation <N>` if anything is later found broken.

- [x] **Step 2: Confirm nothing pacman-managed was removed**

```bash
pacman -Qe | grep -E "^(ripgrep|fd|bat|fzf|starship|neovim|nodejs|fish|wezterm-nightly-bin|lazygit) "
```
Expected: all of these still show as pacman-installed — Phase 4 (removing superseded
pacman packages) is explicitly **not** part of this plan; it's a separate, deliberate,
per-package decision made later once each Nix-provided tool has been trusted through
real use.

- [x] **Step 3: Confirm the .dotfiles repo is clean**

```bash
cd ~/.dotfiles && git status --short
```
Expected: no unexpected modifications outside what was committed in each task above.

- [x] **Step 4: No commit needed — this task only verifies prior work.**

---

## Phase 4 — cleanup (completed 2026-08-19)

Once the migrated tools had been used and trusted, their superseded pacman
equivalents were removed one at a time via plain `pacman -R <pkg>` (no `-s`,
`-dd`, or `--nodeps`), relying on pacman's own dependency check as the safety
net rather than manually predicting what else might depend on each package.

**Removed (33):** ripgrep, fd, bat, starship, htop, bottom, ncdu, gdu,
git-crypt, git-filter-repo, tree-sitter-cli, yq, screen, wget, aria2, unrar,
lbzip2, yt-dlp, translate-shell, speedtest-cli, ssh-audit, gnu-netcat,
nerdfix, sysz, presenterm, fortune-mod, maven, cmake, rust-analyzer,
luarocks, aws-cli, influx-cli, neovim

**Blocked by pacman (left installed, on purpose — not forced):**
- `fzf` — required by `sysz` (itself now Nix-provided, but its pacman
  metadata still lists this dependency)
- `git` — required by `flatpak-builder`, `git-crypt`, `git-filter-repo`,
  `lazygit`, and `yay`
- `unzip` — required by `luarocks`
- `7zip` — required by `flatpak-builder`
- `qrencode` — required by `gst-plugins-bad`, `pass-otp`
- `zbar` — required by `electrum-ltc`, `gst-plugins-bad`
- `jdk-openjdk` — was required by `maven`; **now unblocked** since `maven`
  itself was removed in this same pass (not re-attempted — left as a
  follow-up for whenever it's convenient, `sudo pacman -R jdk-openjdk`)
- `fish` — required by `fisher` (which stays pacman-managed permanently,
  per Task 5 — this block is expected to be permanent, not a follow-up)

Verified afterward: a fresh fish shell resolves all 30 checkable
Nix-provided replacements for the removed packages correctly (no more
pacman fallback to silently mask a problem), confirming the Nix versions
are genuinely standing on their own now, not just coexisting.
