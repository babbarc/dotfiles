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
