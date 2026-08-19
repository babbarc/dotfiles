{ pkgs, system, whisper-dictation, ... }:
let
  # CPU build. whisper-dictation-vulkan exists in the same flake for the
  # Intel Iris Xe iGPU on this machine if CPU transcription turns out too
  # slow — swap the attribute name below, nothing else changes.
  whisperDictationPkg = whisper-dictation.packages.${system}.default;

  # Upstream's own wrapper only prefixes GI_TYPELIB_PATH with gtk4's and
  # gobject-introspection's own typelib dirs. Verified broken as shipped:
  # `whisper-dictation --help` throws `ImportError: cannot import name GLib,
  # introspection typelib not found`, and after supplying glib's typelib dir
  # by hand, `gi.RepositoryError: Typelib file for namespace 'Graphene',
  # version '1.0' not found` — GTK4 pulls in ~28 packages with their own
  # typelib dir (Graphene, Pango, HarfBuzz, libadwaita, appstream, gstreamer,
  # and more), and only two of them made it into the wrapper. Rather than
  # hand-list all ~28 (fragile — silently stops covering the closure on the
  # next dependency bump), compute GI_TYPELIB_PATH from this package's own
  # actual runtime closure at service-start time. Confirmed working: with
  # this, `whisper-dictation --help` prints its real argparse usage instead
  # of a traceback.
  wrappedBin = pkgs.writeShellScript "whisper-dictation-wrapped" ''
    export GI_TYPELIB_PATH="$(
      nix-store -qR ${whisperDictationPkg} |
        while read -r p; do
          [ -d "$p/lib/girepository-1.0" ] && printf '%s:' "$p/lib/girepository-1.0"
        done
    )$GI_TYPELIB_PATH"
    exec ${whisperDictationPkg}/bin/whisper-dictation "$@"
  '';
in
{
  # ydotool isn't otherwise reachable: whisper-dictation's own wrapper only
  # puts it on *its own* internal PATH, not this user's — verified `command -v
  # ydotool` found nothing before adding it here explicitly. Needed standalone
  # to run `ydotoold` once the manual permission steps below are done.
  home.packages = [ whisperDictationPkg pkgs.ydotool ];

  # jacopone/whisper-dictation ships its own systemd --user unit in
  # $out/lib/systemd/user/, but its ExecStart hardcodes
  # /run/current-system/sw/bin/whisper-dictation — a NixOS system-profile
  # path that doesn't exist on this home-manager-only (non-NixOS) host.
  # Define the unit ourselves against the GI_TYPELIB_PATH-fixed wrapper above
  # instead of linking theirs.
  systemd.user.services.whisper-dictation = {
    Unit = {
      Description = "Whisper Dictation - local push-to-talk speech-to-text";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${wrappedBin}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [ "PYTHONUNBUFFERED=1" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ydotoold needs /dev/uinput, currently root-only — deliberately not
  # auto-started (WantedBy omitted): it would just crash-loop until the
  # manual permission steps below are done. Start it by hand afterwards with
  # `systemctl --user start ydotoold`.
  systemd.user.services.ydotoold = {
    Unit.Description = "ydotool daemon (uinput-based input injection)";
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # NOT handled here, and cannot be from home-manager on a non-NixOS host —
  # both are one-time manual steps with sudo:
  #
  #   1. sudo usermod -aG input USERNAME
  #      then start a fresh login session (group membership doesn't apply to
  #      an already-open one).
  #   2. A udev rule granting the input group access to /dev/uinput, which is
  #      currently root-only (crw------- root root):
  #        echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | \
  #          sudo tee /etc/udev/rules.d/70-uinput.rules
  #        sudo udevadm control --reload-rules && sudo udevadm trigger
  #
  # Default config lands at ~/.config/whisper-dictation/config.yaml on first
  # run (super+period push-to-talk, medium whisper model — ~1.5GB, downloaded
  # on first use via `whisper-cpp-download-ggml-model medium`; drop to `base`
  # or `small` in that file first if the download size or transcription
  # latency isn't worth it for a first test).
}
