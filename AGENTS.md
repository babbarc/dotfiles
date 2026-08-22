# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Nix / home-manager (`nix/`)

This flake drives three hosts from one repo, all under `nix/hosts/<name>/`,
output names role-based (`laptop`, `server`, `wsl`) not username-based:

- **Arch laptop** (`homeConfigurations.laptop`, `nix/hosts/laptop/home.nix`) -
  standalone home-manager, since Arch isn't NixOS and has no NixOS module
  system to hang home-manager off of. This is the machine this repo's
  checkout is not running on live - the deployed copy is a separate checkout
  at `~/.dotfiles`, updated out of band via `home-manager switch` there.
  Validate with:
  `nix build ./nix#homeConfigurations.laptop.activationPackage --no-link` (from repo root).
- **Arch server** (`homeConfigurations.server`, `nix/hosts/server/home.nix`) -
  same standalone shape as the laptop, but imports only the shared
  `nix/modules/dev` bucket - no desktop/GUI modules, since a server has no
  display. Validate with:
  `nix build ./nix#homeConfigurations.server.activationPackage --no-link`.
- **WSL host** (`nixosConfigurations.wsl`, `nix/hosts/wsl/configuration.nix`) -
  a NixOS-WSL system with home-manager wired in as a NixOS module (not
  standalone), since this output *is* a NixOS system - see that file's header
  comment for why that's a structural fit, not a style pick. Nobody has
  installed NixOS-WSL on the Windows machine yet; this output only proves the
  derivation evaluates and builds. Validate with:
  `nix build ./nix#nixosConfigurations.wsl.config.system.build.toplevel --no-link`.
- `nix flake check ./nix` checks all three outputs together.
- **Per-machine values** - machine-specific personal values (usernames,
  hostnames, LAN endpoints) are NOT in the repo. Each machine supplies them in
  `~/.config/dotfiles/env` (gitignored; the committed template is `env.example`
  at the repo root). Nix reads it via the `dotfiles-env` flake input: the input
  defaults to `env.example`, and each machine overrides it with
  `--override-input dotfiles-env path:$HOME/.config/dotfiles/env` (pure eval
  forbids reading the file directly; the override is not written to flake.lock).
  `nix/setup.sh` writes the file and wires the override in. wezterm parses the
  file at runtime (`wezterm/config/env.lua`), fish loads it via
  `fish/conf.d/dotfiles-env.fish`, and `.zshrc` sources it for zsh.
  `dotfilesEnv` is passed via `extraSpecialArgs`/`specialArgs` to the whole
  home-manager module tree, not just the top-level host files - any module
  under `nix/modules/` can take it as a function arg directly (e.g.
  `nix/modules/dev/git.nix` reads `dotfilesEnv.DOTFILES_USER_EMAIL`), though
  most modules instead prefer reading an already-set option like
  `config.home.username` when one carries the same per-machine value, to
  avoid two paths to the same fact.
- **wezterm config is fully self-contained in this repo** - `wezterm/`
  (`wezterm.lua`, `config/`, `utils/`, `events/`) is a complete, independent
  wezterm config with no runtime dependency on the upstream
  `KevinSilvester/wezterm-config` framework (that framework was only ever a
  starting point; the still-useful parts of it were vendored in, MIT
  attribution headers included, and re-themed - `utils/backdrops.lua`,
  `utils/gpu-adapter.lua`, and `colors/custom.lua` were dropped rather than
  vendored, since they were the source of a hardcoded-color/theme-mismatch
  bug rather than something worth keeping). The laptop gets it via
  `nix/modules/wezterm.nix` symlinking the whole tree into
  `~/.config/wezterm`; Windows gets it via `wezterm/setup-windows.ps1`
  fetching the same files as raw content from the public GitHub mirror. Both
  hosts run byte-identical config by construction - see
  `wezterm/config/appearance.lua`'s comments for the reasoning behind its
  settings before changing them, especially `front_end`/`window_background_opacity`
  (WebGpu + opacity + a background image was a real, evidenced bug class,
  not just a style choice).
- **Windows wezterm** - Windows machines don't run nix; they only consume
  wezterm's config. `wezterm/setup-windows.ps1` is the Windows-side guided
  setup (the counterpart to `nix/setup.sh`, no git required - it only
  downloads files over HTTPS): it fetches all of `wezterm/`'s files as raw
  content from the public GitHub mirror into `%USERPROFILE%\.config\wezterm`,
  migrates away any leftover `KevinSilvester/wezterm-config` clone from an
  older version of this script (its `.git`, `backdrops/`, `colors/`, and the
  two dropped `utils/*.lua` files), and writes
  `%USERPROFILE%\.config\dotfiles\env` with exactly the 2 Windows-relevant
  keys (`WEZTERM_WSL_SYSTEM_USER` + `WEZTERM_GIT_BASH_PATH`;
  `DOTFILES_SERVER_*`/`JOY_CONSOLE_*`/`STEREO_*` are never written there,
  since nothing on the Windows side reads them). See README's 'Windows
  wezterm' section under Bootstrap.
- **Fresh-machine bootstrap** - `nix/setup.sh` is the single guided installer
  for all three hosts: detects the role (distro NixOS -> wsl, hostname `laptop`
  -> laptop, else prompts with default server; `--role`/`SETUP_ROLE` override),
  asks where to fetch the repo from (LAN Gitea tarball / GitHub mirror /
  existing checkout; nix-only via `nix-prefetch-url --unpack`, git only when
  present and chosen), prompts ONLY the role's env keys (every role:
  `DOTFILES_USERNAME` + `DOTFILES_USER_EMAIL` + `DOTFILES_HOST_ROLE` fixed to
  the role; laptop adds its server/joy-console/stereo keys; `WEZTERM_*` are
  Windows-side only and never
  prompted or written), writes `~/.config/dotfiles/env` with exactly those keys
  (anything else in an existing file is dropped on rewrite, mentioned in the
  summary), then builds with
  `--override-input dotfiles-env path:$HOME/.config/dotfiles/env` and activates
  per role (laptop/server -> `homeConfigurations.<role>.activationPackage` +
  `HOME_MANAGER_BACKUP_EXT=backup ./result/activate`; wsl on NixOS ->
  `nixosConfigurations.wsl.config.system.build.toplevel` + `sudo
  ./result/bin/switch-to-configuration switch`; wsl elsewhere ->
  `homeConfigurations.server`). See README's 'Bootstrap'; `--dry-run` previews
  without changing anything.
- **Every flake switch needs the env override** - `nixos-rebuild switch`/
  `home-manager switch --flake ...` WITHOUT `--override-input dotfiles-env
  path:$HOME/.config/dotfiles/env` silently rebuilds with the committed
  `env.example` placeholder values (verified: username becomes `your-username`).
  Both tools accept `--override-input` (home-manager passes it through;
  nixos-rebuild at the locked nixpkgs rev is nixos-rebuild-ng, which supports
  it). Never print a bare switch command in docs.
- **Flake refs must be the repo-ROOT `?dir=nix` form** - never a bare absolute
  path into `nix/` (`~/.dotfiles/nix#...` or `path:.../dotfiles/nix#...`).
  Modules under `nix/modules/dev/` reference repo-root files (`nvim/`, `fish/`,
  etc.) via `../../../` relative paths, so the flake source must be the whole
  repo. An absolute `nix/`-directory path ref makes nix treat `nix/` as the
  source, those paths escape to `/nix/store`, and pure eval fails with
  "access to absolute path '/nix/store/nvim/lua' is forbidden". The working
  form is the repo ROOT: `path:.../dotfiles?dir=nix#...` (or
  `~/.dotfiles?dir=nix#...`). A RELATIVE git ref like `./nix#...` from inside
  the repo is fine (git-flake semantics use the whole git tree). Tarball/git-URL
  flakes already source the whole repo and use `?dir=nix` in the URL.
- **A NixOS option referencing arbitrary on-disk paths outside the flake's
  inputs (e.g. `security.pki.certificateFiles`, see the wsl host's
  `DOTFILES_CORPORATE_CA_DIR` - a directory whose regular
  .pem/.crt/.cer/.cert files are enumerated at eval time via
  `builtins.readDir`) needs two fixes, not one, confirmed by hand**: (1) each
  file path must be a real Nix `path` (e.g. `/. + someString`), not a bare
  string - a bare string reaches the consuming derivation's build phase
  unresolved, and that build runs sandboxed with no access to paths outside
  the Nix store, failing with "No such file or directory"; (2) even after
  that, flakes evaluate in pure mode by default, which refuses to import an
  out-of-flake path into the store at all ("access to absolute path ... is
  forbidden in pure evaluation mode") - only `nix build --impure` resolves
  this. `nix/setup.sh` adds `--impure` to its build command automatically,
  and only when such a key is actually set, so the common/default (unset)
  case stays fully pure. A missing or empty directory degrades to no
  certificates rather than a hard eval error.
- **That declarative `security.pki.certificateFiles` wiring only protects the
  ACTIVATED system, not `nix/setup.sh`'s own bootstrap fetches** - on a
  corporate network, the script's `nix build`/`nix-prefetch-url`/`git clone`
  calls need CA trust before the system generation that would set the
  option has even been built (chicken-and-egg). `nix/setup.sh` covers this
  earlier moment separately: it reuses the same `DOTFILES_CORPORATE_CA_DIR`
  to assemble a CA bundle (system default bundle + every file in the
  directory) at the persistent path `~/.config/dotfiles/bootstrap-ca.crt`
  (regenerated/overwritten on every run, not `mktemp`'s default `/tmp` - see
  next entry for why) for the script's own process, and exports it via
  `NIX_SSL_CERT_FILE`/`SSL_CERT_FILE`/`GIT_SSL_CAINFO` before `fetch_repo`/the
  build run. This is in addition to, not instead of, the declarative option
  above.
- **`NIX_SSL_CERT_FILE`/`SSL_CERT_FILE` only cover fetches nix/setup.sh's own
  process makes directly (nix-prefetch-url, git clone, flake-input
  evaluation) - they never reach a multi-user nix-daemon's OWN fetches
  (substituter/binary-cache downloads, fixed-output-derivation builds),
  confirmed by hand against nix 2.35.2**: a sandboxed FOD build's `/tmp` is
  private per-build, so a bundle path under `mktemp`'s `/tmp` is not reliably
  visible where the daemon might need it - persisting it under `$HOME` (as
  above) fixes that half. But separately, and regardless of path, the daemon
  computes its `ssl-cert-file` setting from *its own* (systemd-service)
  process environment, not the connecting client's - a client-exported env
  var never reaches the daemon at all, verified with
  `NIX_SSL_CERT_FILE=/bogus nix build --option ssl-cert-file /bogus <FOD
  expr>`, which builds using the daemon's own default with no error. An
  explicit `--option ssl-cert-file <path>` on the `nix build` command line
  (which `nix/setup.sh` also passes) *does* reach the daemon's `SetOptions`
  handshake, but the daemon only honors it when the connecting user is in
  `nix.settings.trusted-users`. `nix/hosts/wsl/configuration.nix` now
  declares the login user trusted there (see its `nix.settings.trusted-users`
  comment for the security tradeoff and why it's the named user, not
  `@wheel`, even though nixos-wsl's own `wsl.defaultUser` module already puts
  that user in `wheel` for sudo) - but this is DECLARATIVE and so only takes
  effect after a generation built with it has been activated once; it cannot
  help `nix/setup.sh`'s very first bootstrap run on a fresh machine
  (chicken-and-egg, same as everything else in this list). Until that first
  activation, or on any host that hasn't added this setting, the daemon logs
  "ignoring the client-specified setting 'ssl-cert-file' ... you are not a
  trusted user" and silently keeps its own default - the workaround for that
  one-time first run is `sudo nix/setup.sh` (root is trusted by default). If
  a corporate-network bootstrap still hits SSL errors on package/binary-cache
  downloads after the CA bundle is wired up and this is genuinely the first
  run, this daemon-side gap is the near-certain reason, not a mistake in the
  client-side wiring.
- **`nix.settings.trusted-users` is a `listOf`-typed NixOS option, so a plain
  assignment in a host config file ADDS to nixpkgs' own default of
  `[ "root" ]` rather than replacing it** - confirmed by reading
  `nixos/modules/config/nix.nix` (the default is set as a plain
  `trusted-users = [ "root" ]`, not via `mkDefault`, so it merges with any
  other plain-priority definition of the same list option) and by `nix eval
  ./nix#nixosConfigurations.wsl.config.nix.settings.trusted-users`, which
  returns both `"root"` and the configured login user. No need to spell out
  `"root"` explicitly alongside the login user in a host config - it's
  already there by default and doesn't need re-adding.

Portable dev tooling (shell, editor, language toolchains, git/CLI utilities,
agent-CLI config) lives in `nix/modules/dev/` (imported as a unit via
`nix/modules/dev/default.nix`) and is shared by all three hosts - it must stay
free of anything assuming a display server or Arch-specific integration.
Desktop/GUI modules (`sway.nix`, `waybar.nix`, `wezterm.nix`, `fonts.nix`,
`voice-dictation.nix`, `session-path.nix`) stay directly under `nix/modules/`,
Arch-only, imported only by `nix/hosts/laptop/home.nix`. **SSH/GPG keys and
anything credential-shaped are out of scope for this repo on all hosts** -
they are never centralized in `modules/dev/`; set them up per-machine outside
Nix.

- Flakes only see git-tracked files. A new file under `nix/modules/`, `nix/hosts/`
  (or any path the flake reads) must be `git add`-ed (at least `git add -N` for an
  empty placeholder) before `nix build`/`nix flake` will notice it - otherwise you
  get a confusing "in the left operand of the update (//) operator" eval error
  from home-manager's internals instead of a clear "file not found".
- Dotfiles get pulled under home-manager management by adding a small module that
  maps each file via `xdg.configFile."<app>/<relative-path>".source = ../../../<app>/<relative-path>;`
  (three `../` from `nix/modules/dev/*.nix`, two from `nix/modules/*.nix`), then
  adding that module to the relevant `imports` list (`nix/modules/dev/default.nix`
  for shared modules, `nix/hosts/laptop/home.nix` for Arch-only ones). See `nix/modules/wezterm.nix`,
  `nix/modules/sway.nix`, `nix/modules/waybar.nix` for examples. Before wiring up a new
  app this way, check whether its config files reference each other or other config by
  absolute `~/.config/...` path - that breaks once home-manager replaces them with
  read-only Nix-store symlinks (wezterm.nix's header comment documents a real instance
  of this class of problem).
- **Podman quadlets** (systemd units describing rootless containers) are vendored the
  same way: `nix/modules/dev/browser-proxy-firstmate.nix` copies a `.container` file
  from `containers/systemd/` in this repo to `~/.config/containers/systemd/` via
  `xdg.configFile` - confirmed on this host (podman 6.1.0) as the directory podman's
  user-level quadlet generator actually reads to produce a systemd --user unit; don't
  assume that path without checking it holds on whatever nixpkgs/podman version is
  current. This repo does NOT install podman itself (no package declares it anywhere
  under `nix/` - it's a system package outside home-manager's scope on this host) and
  does NOT script building the container images quadlets depend on (`podman build
  -f Containerfile...` stays a manual, occasional step by design - never add a nix
  activation script that runs a podman build). The captain's separate *production*
  browser-proxy instance (hermes-agent repo, `browser-proxy.container`, ports
  3333/3334) is NOT managed by this repo at all - it runs under a distinct system
  user account on this host, set up by hand entirely outside of nix; don't assume its
  existence implies a pattern to extend here beyond what `browser-proxy-firstmate.nix`
  already establishes. A quadlet's own dependencies (e.g. a script it bind-mounts via
  `Volume=`) get vendored the same way rather than requiring a live clone of their
  source repo on this host: `browser-proxy-firstmate.py` is a synced copy of
  hermes-agent's `browser-proxy.py`, materialized alongside the quadlet unit at
  `~/.config/containers/systemd/browser-proxy-firstmate.py`, with the quadlet's
  `Volume=` line pointing at that materialized path instead of a path under
  `~/hermes-agent`. Keep both copies in sync by hand if hermes-agent's script changes.
- `herdr/config.toml` is templated, not `.source`-linked: it carries a
  `__FISH_SHELL_PATH__` placeholder for `default_shell` that `nix/modules/dev/herdr.nix`
  substitutes with `$HOME/.nix-profile/bin/fish` (home-manager-path installs into the
  user's default nix profile) via `builtins.replaceStrings` + `.text`. Keep the
  placeholder - replacing it with a literal path would hardcode one host's user and
  break the others (each host's username comes from its per-machine
  `~/.config/dotfiles/env` file, not from this repo - see `env.example`).
- Non-nix-packaged tools (no nixpkgs entry, no binary cache) bootstrap themselves via a
  `home.activation.<name> = lib.hm.dag.entryAfter [ "writeBoundary" ] '' ... '';` block: guard
  with `command -v <tool>` so an already-bootstrapped machine's switch stays a fast no-op, and
  `||`-guard the install command so a failed curl/npm only warns on stderr instead of failing
  the whole `home-manager switch`. Two gotchas make these blocks fragile (both fixed in
  `nix/modules/dev/herdr.nix` and `nix/modules/dev/agent-cli-tools.nix`): (1) every activation
  script REPLACES PATH with only pinned store utils (bash/coreutils/grep/sed/jq - no /usr/bin,
  no ~/.local/bin, no curl/tar/awk), so a block must re-prefix PATH with `$HOME/.local/bin`
  (so `command -v` sees already-installed tools and the block no-ops) plus the store-pinned
  tool dirs any piped installer needs by bare name (curl, and gawk/gnutar as needed); (2)
  `home.file`/`xdg.configFile` content is linked at `linkGeneration`, which runs AFTER
  `writeBoundary`, so an install block cannot rely on a home.file (e.g. ~/.npmrc) existing -
  pass any needed config (like npm's `--prefix "$HOME/.local"`) explicitly on the command line.
  See `nix/modules/dev/pi.nix` (settings.json merge), `nix/modules/dev/firstmate.nix`,
  `nix/modules/dev/herdr.nix`, and `nix/modules/dev/agent-cli-tools.nix` for worked examples.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
