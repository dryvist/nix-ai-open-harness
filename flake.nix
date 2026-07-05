{
  description = "Declarative local-LLM fallback harness for Crush and MiMoCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    dryvist-github = {
      url = "github:dryvist/.github";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      home-manager,
      flake-parts,
      nix-ai-tools,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.dryvist-github.flakeModules.dev-hygiene
      ];

      flake.homeManagerModules.default = {
        imports = [ ./modules ];
        _module.args.nix-ai-tools = nix-ai-tools;
      };

      perSystem =
        { pkgs, system, ... }:
        let
          aiPackages = nix-ai-tools.packages.${system};
        in
        {
          packages = {
            inherit (aiPackages) crush mimo-code;
            default = pkgs.symlinkJoin {
              name = "nix-ai-open-harness-tools";
              paths = [
                aiPackages.crush
                aiPackages.mimo-code
              ];
            };
          };

          checks = import ./lib/checks.nix {
            inherit
              home-manager
              pkgs
              system
              ;
            homeModule = self.homeManagerModules.default;
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.deadnix
              pkgs.nixfmt-tree
              pkgs.statix
            ];
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
