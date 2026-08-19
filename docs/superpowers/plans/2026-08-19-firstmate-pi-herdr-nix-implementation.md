# Firstmate + Pi/Herdr Nix Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring firstmate's toolchain, herdr's `config.toml`, and pi's genuinely-user settings under home-manager, without touching the herdr binary, pi's runtime-written settings fields, or the firstmate repo's own contents.

**Architecture:** Three independent home-manager modules in `~/.dotfiles/nix/modules/`, each imported from `~/.dotfiles/nix/home.nix`. `firstmate.nix` is pure package/env-var declaration (lowest risk, no pre-existing files to conflict with). `herdr.nix` reuses the exact "copy into repo, symlink back, leave runtime files alone" pattern already used for `lazygit.nix` (and already designed, never executed, for herdr itself in the prior migration's Task 9). `pi.nix` is the one genuinely new pattern in this repo: a `jq`-based `home.activation` merge instead of a symlink, because `settings.json` mixes user-owned fields with fields pi itself rewrites at runtime.

**Tech Stack:** Nix flakes, standalone home-manager (`nix-community/home-manager`), nixpkgs unstable, `jq`. No new flake inputs.

**Spec:** `docs/superpowers/specs/2026-08-19-firstmate-pi-herdr-nix-design.md`

## Global Constraints

- Cache-fetched packages only — no from-source builds (constraint carried over from the parent `2026-08-19-nix-migration-design.md` project; this is why the herdr *binary* stays outside Nix entirely, unchanged from that decision).
- `~/firstmate` (already cloned) and `~/.local/bin/herdr` (already installed) are never modified by any task below — only their *configuration* is in scope.
- Every `home-manager switch` in this plan uses `-b backup` (`home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup`), matching this repo's established invocation.
- Only files this plan actually creates/modifies get `git add`ed at each commit — the working tree has unrelated in-progress changes (`nix/home.nix` diff for `session-path.nix`, `nvim/` edits) that must NOT be swept in.

---

## File Structure

- `nix/modules/firstmate.nix` (new) — `gh`/`jq` packages, `FM_HOME`/`FM_BACKEND` env vars.
- `herdr/config.toml` (new, at repo root alongside `lazygit/`, `wezterm/`) — copied from `~/.config/herdr/config.toml`, the physical source home-manager symlinks from.
- `nix/modules/herdr.nix` (new) — `xdg.configFile` pointing at the above.
- `nix/modules/pi.nix` (modified) — adds the `jq` merge activation script on top of the existing `pi-coding-agent` package declaration.
- `nix/home.nix` (modified) — adds `./modules/firstmate.nix` and `./modules/herdr.nix` to `imports`.

---

### Task 1: firstmate.nix — toolchain and env vars

**Files:**
- Create: `~/.dotfiles/nix/modules/firstmate.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `gh`, `jq` on `PATH`; `$FM_HOME` = `/home/USERNAME/firstmate`; `$FM_BACKEND` = `herdr`. Task 3's activation script references `pkgs.jq` directly (via store path), so it does not depend on this task's `jq` package entry — the two are independent, duplication is harmless.

- [ ] **Step 1: Confirm current state before changing anything**

```bash
which gh jq; echo "FM_HOME=$FM_HOME FM_BACKEND=$FM_BACKEND"
```

Expected: `gh` not found (or a non-Nix path); `jq` resolves to `/usr/bin/jq` (pacman, not Nix); both env vars empty.

- [ ] **Step 2: Write the module**

```nix
{ config, pkgs, ... }:
{
  # ~/firstmate is a plain git clone (github:kunchenguid/firstmate), not
  # nix-tracked — same posture as ~/.dotfiles itself and wezterm's upstream
  # config clone (see wezterm.nix). Update it via firstmate's own
  # /updatefirstmate skill or `git pull`, not via this module.
  #
  # Pi's firstmate-supervision watcher extension lives inside that clone
  # (~/firstmate/.pi/extensions/*.ts) and auto-loads once `pi` is launched
  # from ~/firstmate and the project trust prompt is approved once — no nix
  # wiring needed for it.
  home.packages = with pkgs; [
    gh   # firstmate requires `gh auth login` for PR creation
    jq   # required by the herdr runtime backend for JSON responses
  ];

  home.sessionVariables = {
    FM_HOME = "${config.home.homeDirectory}/firstmate";
    # Pins the runtime backend declaratively instead of relying on
    # HERDR_ENV auto-detection, per firstmate's backend precedence
    # (docs/configuration.md: --backend flag > FM_BACKEND > config/backend
    # file > auto-detect > default tmux).
    FM_BACKEND = "herdr";
  };
}
```

Save to `~/.dotfiles/nix/modules/firstmate.nix`.

- [ ] **Step 3: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/firstmate.nix` to the `imports` list (any position; alphabetical-ish ordering already used there — place it near `./modules/pi.nix`).

- [ ] **Step 4: Switch**

```bash
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
```

Expected: succeeds, no from-source build (both `gh` and `jq` are common cached nixpkgs packages).

- [ ] **Step 5: Verify**

```bash
exec fish -c 'which gh jq; echo "FM_HOME=$FM_HOME FM_BACKEND=$FM_BACKEND"'
```

Expected: `gh` and `jq` resolve under `/nix/store/`; `FM_HOME=/home/USERNAME/firstmate FM_BACKEND=herdr`.

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles && git add nix/modules/firstmate.nix nix/home.nix && git commit -m "nix(firstmate): declare gh/jq toolchain and FM_HOME/FM_BACKEND env vars"
```

---

### Task 2: herdr.nix — config.toml only

**Files:**
- Create: `~/.dotfiles/herdr/config.toml`
- Create: `~/.dotfiles/nix/modules/herdr.nix`
- Modify: `~/.dotfiles/nix/home.nix` (imports list)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `~/.config/herdr/config.toml` symlinked from the nix store; `~/.config/herdr/{session.json,.plugins.lock,herdr-client.log,herdr-server.log}` remain plain, unmanaged, writable files.

- [ ] **Step 1: Copy the config into the dotfiles repo**

```bash
mkdir -p ~/.dotfiles/herdr
cp ~/.config/herdr/config.toml ~/.dotfiles/herdr/config.toml
```

- [ ] **Step 2: Secret-scan before committing**

```bash
grep -inE "sk-|api[_-]?key\s*=|token\s*=\s*\"[A-Za-z0-9]|bearer" ~/.dotfiles/herdr/config.toml
```

Expected: no output. If anything matches, stop and redact that line before proceeding — do not commit it.

- [ ] **Step 3: Write the module**

```nix
{ ... }:
{
  # herdr itself is deliberately outside Nix (not in nixpkgs, no binary
  # cache, would require a from-source build — see the parent nix-migration
  # project's Task 9). It stays installed via its own curl installer at
  # ~/.local/bin/herdr, self-updating via `herdr update` / `herdr channel
  # set`. This module never touches the binary.
  #
  # Only config.toml is genuinely user config. session.json, .plugins.lock,
  # and the two .log files are runtime-written and stay unmanaged plain
  # files — same split already used for lazygit's config.yml/state.yml.
  xdg.configFile."herdr/config.toml".source = ../../herdr/config.toml;
}
```

Save to `~/.dotfiles/nix/modules/herdr.nix`.

- [ ] **Step 4: Add the import**

In `~/.dotfiles/nix/home.nix`, add `./modules/herdr.nix` to the `imports` list.

- [ ] **Step 5: Switch**

```bash
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
```

Expected: succeeds. Since `~/.config/herdr/config.toml` already exists as a plain file, home-manager backs it up (suffixed `.backup` by the `-b backup` flag) before placing its own symlink.

- [ ] **Step 6: Verify**

```bash
readlink -f ~/.config/herdr/config.toml   # should resolve into /nix/store/
head -3 ~/.config/herdr/config.toml       # should show the migrated content
ls ~/.config/herdr/                       # session.json, .plugins.lock, *.log still present
herdr --version                           # still 0.8.0 — binary untouched
```

Expected: symlink resolves under `/nix/store/`; content matches what was copied in Step 1; `session.json`/`.plugins.lock`/both `.log` files are still plain files (not symlinks — confirm with `ls -la` if in doubt); `herdr --version` unchanged.

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles && git add herdr nix/modules/herdr.nix nix/home.nix && git commit -m "nix(herdr): manage config.toml via home-manager, binary stays outside Nix"
```

---

### Task 3: pi.nix — settings.json merge activation script

**Files:**
- Modify: `~/.dotfiles/nix/modules/pi.nix`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `~/.pi/agent/settings.json` with `theme`/`hideThinkingBlock`/`steeringMode`/`followUpMode` reasserted to declared values on every `home-manager switch`, while `defaultProvider`/`defaultModel`/`lastChangelogVersion` (and any other pi-written field) pass through unchanged.

- [ ] **Step 1: Confirm current state before changing anything**

```bash
cat ~/.pi/agent/settings.json
```

Expected (current, pre-change):
```json
{
  "lastChangelogVersion": "0.84.2",
  "theme": "dark",
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-v4-flash",
  "defaultThinkingLevel": "high"
}
```

- [ ] **Step 2: Write the updated module**

Replace the full contents of `~/.dotfiles/nix/modules/pi.nix` with:

```nix
{ config, lib, pkgs, ... }:
let
  managedDefaults = {
    theme = "rose-pine-moon";
    hideThinkingBlock = true;
    steeringMode = "all";
    followUpMode = "all";
  };
  settingsDefaultsFile = pkgs.writeText "pi-settings-defaults.json" (builtins.toJSON managedDefaults);
  settingsPath = "${config.home.homeDirectory}/.pi/agent/settings.json";
in
{
  home.packages = with pkgs; [
    pi-coding-agent
  ];

  # settings.json mixes genuinely-user fields (theme, hideThinkingBlock,
  # steeringMode, followUpMode) with fields pi itself writes at runtime
  # (defaultProvider/defaultModel on interactive model switches;
  # lastChangelogVersion on changelog view). A home.file symlink would make
  # the whole file read-only and break those writes, so this merges the
  # managed defaults into the existing file on every switch instead of
  # replacing it — jq's `*` keeps the right-hand object's keys, and any
  # left-hand key not present on the right (i.e. every pi-written field)
  # survives untouched.
  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="${settingsPath}"
    mkdir -p "$(dirname "$settings_file")"
    if [ -f "$settings_file" ]; then
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        "$settings_file" ${settingsDefaultsFile} \
        > "$settings_file.tmp" && $DRY_RUN_CMD mv "$settings_file.tmp" "$settings_file"
    else
      $DRY_RUN_CMD cp ${settingsDefaultsFile} "$settings_file"
    fi
  '';
}
```

- [ ] **Step 3: Switch**

```bash
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
```

Expected: succeeds. `settings.json` is a plain file the whole time (never symlinked), so no backup-flag conflict occurs here — the activation script edits it in place.

- [ ] **Step 4: Verify the merge applied and runtime fields survived**

```bash
cat ~/.pi/agent/settings.json
```

Expected:
```json
{
  "lastChangelogVersion": "0.84.2",
  "theme": "rose-pine-moon",
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-v4-flash",
  "defaultThinkingLevel": "high",
  "hideThinkingBlock": true,
  "steeringMode": "all",
  "followUpMode": "all"
}
```

(Exact key order may differ — `jq -s '.[0] * .[1]'` doesn't guarantee ordering. Check field values, not order.)

- [ ] **Step 5: Prove the merge doesn't clobber a runtime write**

Simulate pi itself changing the default model (as it would on an interactive `/model` switch), without needing to actually launch pi:

```bash
jq '.defaultModel = "deepseek-v4-pro"' ~/.pi/agent/settings.json > /tmp/pi-settings-sim.json \
  && mv /tmp/pi-settings-sim.json ~/.pi/agent/settings.json
home-manager switch --flake ~/.dotfiles/nix#USERNAME -b backup
cat ~/.pi/agent/settings.json
```

Expected: `defaultModel` is still `"deepseek-v4-pro"` (the simulated runtime write survived the switch), and `theme`/`hideThinkingBlock`/`steeringMode`/`followUpMode` are still at their managed values from Step 4. This is the core guarantee the design depends on — if `defaultModel` got reset to anything else here, the merge logic is wrong and must be fixed before committing.

- [ ] **Step 6: Restore the pre-simulation model value**

```bash
jq '.defaultModel = "deepseek-v4-flash"' ~/.pi/agent/settings.json > /tmp/pi-settings-restore.json \
  && mv /tmp/pi-settings-restore.json ~/.pi/agent/settings.json
```

(No `home-manager switch` needed here — this just undoes the Step 5 simulation so the machine's actual pi config isn't left pointing at a model the user didn't choose.)

- [ ] **Step 7: Commit**

```bash
cd ~/.dotfiles && git add nix/modules/pi.nix && git commit -m "nix(pi): merge theme/hideThinkingBlock/steeringMode/followUpMode into settings.json, preserve runtime-written fields"
```

---

## Self-Review Notes

- **Spec coverage:** all three spec sections (firstmate.nix, herdr.nix, pi.nix data-flow) map 1:1 to Tasks 1–3; the spec's "Testing" section is covered by each task's own verify step plus Task 3 Step 5's runtime-preservation proof; the spec's "Open items for the user" (firstmate's own interactive bootstrap) is intentionally not a task here.
- **No placeholders:** every step has literal file contents or literal shell commands; no "add tests for the above" or "similar to Task N" shortcuts.
- **Type/name consistency:** `settingsPath`, `managedDefaults`, `settingsDefaultsFile` are used consistently within Task 3's single file; no cross-task function signatures to check since each module is independent (per the Interfaces blocks above, no task's output is consumed by another).
