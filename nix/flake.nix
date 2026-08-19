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
  };

  outputs = { self, nixpkgs, home-manager, fisher, ... }:
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
      homeConfigurations."USERNAME" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit system fisher; };
        modules = [ ./home.nix ];
      };
    };
}
