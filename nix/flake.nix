{
  description = "USERNAME's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # fisher isn't packaged in nixpkgs and has no flake of its own — it's just
    # two plain fish files (functions/fisher.fish, completions/fisher.fish).
    # `flake = false` pulls the raw source tree instead of expecting flake outputs.
    fisher = {
      url = "github:jorgebucaran/fisher";
      flake = false;
    };
    # No nixosModules/homeManagerModules — a plain package (packages.<system>.default)
    # plus a systemd user unit copied into $out/lib/systemd/user. Its own unit's
    # ExecStart is a NixOS system-profile path, so voice-dictation.nix defines its
    # own systemd.user.services entry against this package's real store path
    # instead of linking theirs. Arch-host-only input - voice-dictation.nix is a
    # desktop-only module, never imported by the wsl host below.
    whisper-dictation.url = "github:jacopone/whisper-dictation";
    # NixOS running as the WSL2 distro itself, for the wsl host below.
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, fisher, whisper-dictation, nixos-wsl, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # unrar is nixpkgs' unfreeRedistributable; keep this exception list to
        # explicitly-audited packages only, don't widen it casually.
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "unrar" ];
      };
    in
    {
      homeConfigurations.laptop = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit system fisher whisper-dictation; };
        modules = [ ./hosts/laptop/home.nix ];
      };

      # Arch server host - same standalone home-manager shape as the laptop
      # (Arch isn't NixOS, so no NixOS module system to hang home-manager off
      # of), but only imports the portable nix/modules/dev bucket: a server
      # has no display, so none of the laptop's desktop/GUI modules apply.
      homeConfigurations.server = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit fisher; };
        modules = [ ./hosts/server/home.nix ];
      };

      # NixOS-WSL host on the Windows machine. home-manager is wired in as a
      # NixOS module (rather than standalone, as the Arch host above uses)
      # because this output is itself a NixOS system - see hosts/wsl/configuration.nix's
      # header comment for why that's the natural fit here, not a style pick made
      # in a vacuum.
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit fisher; };
        modules = [
          nixos-wsl.nixosModules.default
          home-manager.nixosModules.home-manager
          ./hosts/wsl/configuration.nix
        ];
      };
    };
}
