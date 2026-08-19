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
  #
  # nix-store must be referenced by its Nix-managed store path (pkgs.nix),
  # not bare on PATH: systemd --user's own PATH is
  # `~/.nix-profile/bin:/usr/local/bin:/usr/bin` (verified with `systemd-run
  # --user --pipe --wait -- sh -c 'command -v nix-store'`) — it never
  # includes the base Nix installation's own bin dir the way an interactive
  # login shell does. A bare `nix-store` call here silently resolved to
  # nothing, GI_TYPELIB_PATH came out empty, and the service hit the exact
  # same ImportError this wrapper exists to fix.
  wrappedBin = pkgs.writeShellScript "whisper-dictation-wrapped" ''
    export GI_TYPELIB_PATH="$(
      ${pkgs.nix}/bin/nix-store -qR ${whisperDictationPkg} |
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
  # WantedBy=graphical-session.target, tried first, silently never fired:
  # that target is never activated on this host at all (verified `systemctl
  # --user is-active graphical-session.target` -> inactive, and confirmed
  # `~/.dotfiles/sway/config` has no `systemctl --user import-environment` /
  # session-target integration — sway is launched without binding it). The
  # only unit actually active in this systemd --user session is
  # default.target, so both services below bind to that instead.
  systemd.user.services.whisper-dictation = {
    Unit = {
      Description = "Whisper Dictation - local push-to-talk speech-to-text";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "${wrappedBin}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [ "PYTHONUNBUFFERED=1" ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.ydotoold = {
    Unit.Description = "ydotool daemon (uinput-based input injection)";
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Both one-time manual sudo steps are done (usermod -aG input, the
  # /dev/uinput udev rule, and /etc/modules-load.d/uinput.conf so the uinput
  # kernel module — not loaded by default on this host — comes up at boot
  # before anything tries to open the device). Verified across a real
  # reboot: module loaded with no manual modprobe, /dev/uinput came up
  # crw-rw---- root:input, both services now start unprompted.
  #
  # Default config lands at ~/.config/whisper-dictation/config.yaml on first
  # run (super+period push-to-talk, medium whisper model — ~1.5GB, downloaded
  # on first use via `whisper-cpp-download-ggml-model medium`; drop to `base`
  # or `small` in that file first if the download size or transcription
  # latency isn't worth it for a first test).
}
