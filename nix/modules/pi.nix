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
    $DRY_RUN_CMD mkdir -p "$(dirname "$settings_file")"
    if [ -f "$settings_file" ]; then
      if [ -n "$DRY_RUN_CMD" ]; then
        $DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$settings_file" ${settingsDefaultsFile}
      else
        # Guarded by the DRY_RUN_CMD check above so --dry-run never touches the
        # filesystem here: the shell's `>` redirection would otherwise create
        # $settings_file.tmp regardless of what $DRY_RUN_CMD prefixes the
        # command with. On jq failure, clean up the (truncated) tmp file
        # instead of leaving it to clutter/interfere on the next switch.
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
          "$settings_file" ${settingsDefaultsFile} \
          > "$settings_file.tmp" || { rm -f "$settings_file.tmp"; exit 1; }
        mv "$settings_file.tmp" "$settings_file"
      fi
    else
      # install -m 644, not cp: ${settingsDefaultsFile} is a pkgs.writeText
      # output (mode 0444 in the nix store), and plain `cp` propagates that
      # read-only mode to the fresh destination on this machine's coreutils —
      # which would hand pi a read-only settings.json on first run, the exact
      # failure mode this activation-script design exists to avoid.
      $DRY_RUN_CMD install -m 644 ${settingsDefaultsFile} "$settings_file"
    fi
  '';
}
