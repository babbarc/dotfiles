{
  description = "USERNAME's home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
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
        extraSpecialArgs = { inherit system; };
        modules = [ ./home.nix ];
      };
    };
}
