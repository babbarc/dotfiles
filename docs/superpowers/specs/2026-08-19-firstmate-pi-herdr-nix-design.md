# Firstmate + Pi/Herdr Nix Config Design

Date: 2026-08-19

> **Post-implementation note:** the whole-branch code review that followed
> implementation found that `config.toml`'s classification below (under
> `modules/herdr.nix`) as purely user config was wrong — herdr's own binary
> writes to it at runtime too (in-app `prefix+s` settings UI, `herdr config
> reset-keys`), the same kind of runtime-write problem `modules/pi.nix`'s
> settings.json has. Unlike settings.json, though, config.toml doesn't have a
> clean "few managed fields, everything else runtime" split to build a merge
> script against, so it was kept as a whole-file symlink rather than
> redesigned — a deliberate, documented tradeoff, not an oversight. See the
> comment on `xdg.configFile."herdr/config.toml"` in `herdr.nix` for the
> full detail.

## Context

Follow-on to `2026-08-19-nix-migration-design.md`, which moved most CLI/dev
tooling and select dotfiles to home-manager. That migration explicitly
descoped `herdr` as a **package** (not in nixpkgs, no binary cache, would
require a from-source build — see that spec's post-implementation note and
`docs/superpowers/plans/2026-08-19-nix-migration-implementation.md` Task 9).
Task 9's original (never-executed) text already designed the "manage
`config.toml` only, leave the binary alone" pattern this spec reuses.

This project is inspired by two external references on agent-workflow
tooling ([Kun Chen's pi agent config](https://blog.kunchenguid.com/p/kuns-pi-agent-config),
side quests in [the-month-after-leaving-big-tech](https://blog.kunchenguid.com/p/the-month-after-leaving-big-tech))
and adds [firstmate](https://github.com/kunchenguid/firstmate), an agent-distro
for running a crew of coding agents, to this machine — using Pi as the primary
harness and herdr (already installed, self-updating) as the runtime backend.

## Goal

1. Get `firstmate` cloned and usable at `~/firstmate` with `herdr` as its
   runtime backend, with the toolchain it needs declared via home-manager.
2. Bring herdr's `config.toml` under home-manager, following the exact
   config-only pattern Task 9 already designed but never ran.
3. Bring the genuinely user-owned fields of pi's `~/.pi/agent/settings.json`
   under home-manager, without fighting pi's own runtime writes to that same
   file.

## Current state (verified, not assumed)

- `~/firstmate` — cloned this session from `github:kunchenguid/firstmate`.
  Plain git checkout, not nix-tracked, updated via its own `/updatefirstmate`
  skill — same posture as `~/.dotfiles` itself and as wezterm's upstream
  config clone (`wezterm.nix`'s existing comment describes the same pattern).
- Pi's watcher extension for firstmate supervision
  (`~/firstmate/.pi/extensions/fm-primary-pi-watch.ts`,
  `~/firstmate/.pi/extensions/fm-calm.ts`) is bundled inside the firstmate
  repo itself and auto-loads when `pi` is launched from `~/firstmate` and the
  project trust prompt is approved once. **No nix work needed for this.**
- `herdr` 0.8.0 is already installed at `~/.local/bin/herdr` via its own
  curl installer, self-updating via `herdr update`/`herdr channel set`.
  `~/.config/herdr/config.toml` (325 lines) is hand-customized already
  (`default_shell` points at the nix-profile fish path, per the breakage fix
  recorded in the migration implementation doc; `onboarding = false` was
  written by herdr itself after first run). `session.json`, `.plugins.lock`,
  and the two `.log` files are confirmed runtime-written state, same
  conclusion Task 9 reached.
- `~/.pi/agent/settings.json` currently has `defaultProvider: deepseek`,
  `defaultModel: deepseek-v4-flash`, `lastChangelogVersion`, `theme: dark` —
  none of it nix-managed today; `modules/pi.nix` only installs the
  `pi-coding-agent` package.
- Herdr backend selection precedence per firstmate's own docs
  (`docs/configuration.md`): explicit `--backend` flag, then `FM_BACKEND` env
  var, then local gitignored `config/backend` file inside `FM_HOME`, then
  auto-detection from `$TMUX`/`HERDR_ENV=1`/cmux signals, then default `tmux`.
  Herdr also requires `jq` (JSON responses) and optionally `python3`
  (protocol-16 presentation-space ordering — already have `python3` via
  `dev-toolchains.nix`).

## Scope boundary

**In scope:**
- `modules/firstmate.nix` (new) — toolchain packages (`gh`, `jq`) and
  session env vars (`FM_HOME`, `FM_BACKEND`) for firstmate + herdr backend.
- `modules/herdr.nix` (new) — `config.toml` only, via `xdg.configFile`,
  reusing Task 9's original design almost verbatim.
- `modules/pi.nix` (extended) — declarative management of `theme`,
  `hideThinkingBlock`, `steeringMode`, `followUpMode` in
  `~/.pi/agent/settings.json`, via a merge activation script rather than a
  symlink (see Data flow below).

**Explicitly out of scope (deferred, not forgotten):**
- The `herdr` binary itself — stays exactly as installed (curl installer),
  matching Task 9's already-made call. Not revisited here.
- Pi's `defaultProvider`/`defaultModel` — left for the user to change
  interactively as today; nix does not assert a value for these.
- Kun's third-party pi extensions (`pi-web-access`, `codex-fast-mode`,
  `pi-openai-server-compaction`) and personal custom JS extensions (terminal
  status title, aesthetic "calm" mode) — separate from firstmate's own
  `fm-calm.ts`/`fm-primary-pi-watch.ts`, which are already handled (see
  above). A future pass if wanted.
- Pinning firstmate's own git revision as a flake input, or any other
  reproducibility guarantee over the firstmate clone's contents.
- Installing/bootstrapping firstmate's own runtime state (`FM_BACKEND`
  selection is the only firstmate-side config nix touches; project
  registration, secondmates, Relay etc. are the user's own subsequent setup
  inside firstmate).

## Design

### `modules/firstmate.nix` (new)

```nix
{ config, pkgs, ... }:
{
  # ~/firstmate is a plain git clone (github:kunchenguid/firstmate), not
  # nix-tracked — same posture as ~/.dotfiles itself and wezterm's upstream
  # config clone. Update it via firstmate's own /updatefirstmate skill or
  # `git pull`, not via this module.
  #
  # Pi's firstmate-supervision watcher extension lives inside that clone
  # (~/firstmate/.pi/extensions/*.ts) and auto-loads once you launch `pi`
  # from ~/firstmate and approve the project trust prompt — no nix wiring
  # needed for it.
  home.packages = with pkgs; [
    gh   # firstmate requires `gh auth login` for PR creation
    jq   # required by the herdr runtime backend for JSON responses
  ];

  home.sessionVariables = {
    FM_HOME = "${config.home.homeDirectory}/firstmate";
    # Pins the runtime backend declaratively instead of relying on
    # HERDR_ENV auto-detection, per firstmate's own backend precedence
    # (docs/configuration.md: --backend flag > FM_BACKEND > config/backend
    # file > auto-detect > default tmux).
    FM_BACKEND = "herdr";
  };
}
```

### `modules/herdr.nix` (new)

Reuses the "Original Task 9" design from the prior migration's implementation
plan (documented there, never executed) almost exactly: copy the current,
already-customized `config.toml` into the dotfiles repo, symlink it back via
`xdg.configFile`, leave the binary and every runtime-written file alone.

```nix
{ ... }:
{
  # herdr itself is deliberately outside Nix (see
  # docs/superpowers/plans/2026-08-19-nix-migration-implementation.md Task 9
  # — not in nixpkgs, no binary cache, would require a from-source build).
  # It stays installed via its own curl installer at ~/.local/bin/herdr,
  # self-updating via `herdr update` / `herdr channel set`.
  #
  # Only config.toml is genuinely user config. session.json, .plugins.lock,
  # and the two .log files are runtime-written and stay unmanaged plain
  # files — same split already used for lazygit's config.yml/state.yml.
  xdg.configFile."herdr/config.toml".source = ../../herdr/config.toml;
}
```

Migration steps (mirrors Task 9's original text):
1. `mkdir -p ~/.dotfiles/herdr && cp ~/.config/herdr/config.toml ~/.dotfiles/herdr/config.toml`
2. Secret-scan before committing:
   `grep -inE "sk-|api[_-]?key\s*=|token\s*=\s*\"[A-Za-z0-9]|bearer" ~/.dotfiles/herdr/config.toml`
   — expect no output (confirmed clean when this was drafted for Task 9).
3. Write the module, add to `home.nix` imports.
4. `home-manager switch -b backup`, verify `config.toml` resolves to the
   nix-store-symlinked content, `session.json`/`.plugins.lock`/`*.log`
   remain plain writable files.

### `modules/pi.nix` (extended) — data flow for the settings merge

`~/.pi/agent/settings.json` mixes genuinely-user fields (`theme`,
`hideThinkingBlock`, `steeringMode`, `followUpMode`) with fields pi itself
writes at runtime (`defaultProvider`, `defaultModel` on interactive model
switches; `lastChangelogVersion` on changelog view). A `home.file` symlink
would make the whole file read-only and break those runtime writes — so
instead of a symlink, a `home.activation` hook runs a `jq` merge on every
`home-manager switch`:

```nix
{ config, lib, pkgs, ... }:
let
  managedDefaults = {
    theme = "rose-pine-moon";
    hideThinkingBlock = true;
    steeringMode = "all";
    followUpMode = "all";
  };
  settingsPath = "${config.home.homeDirectory}/.pi/agent/settings.json";
in
{
  home.packages = with pkgs; [ pi-coding-agent ];

  home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="${settingsPath}"
    mkdir -p "$(dirname "$settings_file")"
    if [ -f "$settings_file" ]; then
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        "$settings_file" ${pkgs.writeText "pi-settings-defaults.json" (builtins.toJSON managedDefaults)} \
        > "$settings_file.tmp" && $DRY_RUN_CMD mv "$settings_file.tmp" "$settings_file"
    else
      $DRY_RUN_CMD install -m 644 ${pkgs.writeText "pi-settings-defaults.json" (builtins.toJSON managedDefaults)} "$settings_file"
    fi
  '';
}
```

Effect: `theme`/`hideThinkingBlock`/`steeringMode`/`followUpMode` are
reasserted to the nix-declared values on every switch; `defaultProvider`,
`defaultModel`, `lastChangelogVersion`, and any other field pi writes are
passed through unchanged (`jq`'s `*` merge keeps the right-hand object's
keys, left-hand keys not overridden survive). No precedent for this specific
activation-script-merge pattern exists yet in this repo (lazygit/wezterm both
use whole-file ownership because their runtime-written parts are cleanly
separate files) — this is the first "single file, mixed ownership" case.

## Testing

After `home-manager switch -b backup`:
- `which gh jq` resolve under `/nix/store/`; `echo $FM_HOME` is
  `/home/USERNAME/firstmate`; `echo $FM_BACKEND` is `herdr`.
- `cat ~/.config/herdr/config.toml | head -3` shows the migrated content;
  `ls ~/.config/herdr/` still shows `session.json`, `.plugins.lock`, both
  `.log` files as plain files.
- `cat ~/.pi/agent/settings.json` shows the four managed fields at their
  declared values, with `defaultProvider`/`defaultModel`/
  `lastChangelogVersion` unchanged from before the switch.
- Manually switch pi's model interactively, then re-run `home-manager
  switch` — confirm the model choice survives (proves the merge doesn't
  clobber runtime-written fields) and the managed fields are still correct.

## Open items for the user, not this spec

- Firstmate's own bootstrap (`gh auth login` if not already done, project
  registration, choosing project delivery modes) happens interactively
  inside `~/firstmate` on first launch — not scripted here.
