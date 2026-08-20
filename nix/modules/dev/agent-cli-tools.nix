{ lib, pkgs, ... }:
{
  # treehouse, no-mistakes, and the axi suite (gh-axi, chrome-devtools-axi,
  # lavish-axi, tasks-axi, quota-axi) plus gnhf follow the same posture as
  # herdr.nix: none are in nixpkgs, none have a binary cache, and each already
  # ships its own update path — building them from source in Nix would fight
  # that update path on every release instead of using it. This module
  # doesn't package the binaries; it bootstraps each one once per machine via
  # the guarded home.activation blocks below, then gets out of the way -
  # keeping them current is a manual `... update` command, not something a
  # switch does for you (see below).
  #
  # Each block only runs when its tool is missing from PATH, so a switch on
  # an already-bootstrapped machine stays a fast no-op rather than a network
  # call every time, and each is `||`-guarded so a failed curl/npm (e.g. no
  # network) only warns on stderr instead of failing the whole
  # `home-manager switch`.
  #
  # npm-global.nix writes ~/.npmrc via home.file, which lands at the
  # "writeBoundary" dag node - the same node every block below runs after -
  # so the npm install here always has a writable prefix regardless of
  # this module's position in default.nix's import list; no explicit
  # ordering dependency on npm-global.nix is needed.
  #
  # Update (not automated - these tools self-update on their own cadence,
  # and re-running an installer/npm-install on every switch would turn a
  # fast no-op switch into a network call every time):
  #   treehouse update
  #   curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh   (no separate update command)
  #   npm update -g gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf

  home.activation.treehouseInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v treehouse >/dev/null 2>&1; then
      if [ -n "$DRY_RUN_CMD" ]; then
        echo "$DRY_RUN_CMD would install treehouse via: curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh"
      else
        ${pkgs.curl}/bin/curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh \
          || echo "warning: treehouse install failed (offline?) - retry later with: curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh" >&2
      fi
    fi
  '';

  home.activation.noMistakesInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v no-mistakes >/dev/null 2>&1; then
      if [ -n "$DRY_RUN_CMD" ]; then
        echo "$DRY_RUN_CMD would install no-mistakes via: curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh"
      else
        ${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh \
          || echo "warning: no-mistakes install failed (offline?) - retry later with: curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh" >&2
      fi
    fi
  '';

  # A single `npm install -g` call installs the whole suite, so the guard
  # checks all six binaries and installs the whole batch if any is missing -
  # matching how the suite is installed and updated as one unit above.
  home.activation.axiSuiteInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    axi_tools="gh-axi chrome-devtools-axi lavish-axi tasks-axi quota-axi gnhf"
    missing=0
    for t in $axi_tools; do
      command -v "$t" >/dev/null 2>&1 || missing=1
    done
    if [ "$missing" = 1 ]; then
      $DRY_RUN_CMD ${pkgs.nodejs_26}/bin/npm install -g $axi_tools \
        || echo "warning: axi suite npm install failed (offline?) - retry later with: npm install -g $axi_tools" >&2
    fi
  '';
}
