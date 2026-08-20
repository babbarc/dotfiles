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
