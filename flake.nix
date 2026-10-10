{
  description = "Declarative local-LLM fallback harness for Crush and MiMoCode with Homebrew Goose configuration";

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
      url = "github:dryvist/.github?ref=v1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Config source for OpenCode: this repo decides WHETHER the harness ships
    # it (programs.openHarness.opencode); nix-ai owns the option schema and
    # renders ~/.config/opencode/opencode.json. Consumers that also import
    # nix-ai themselves (nix-darwin) follow this input back onto their own to
    # keep a single instance.
    nix-ai = {
      url = "github:dryvist/nix-ai?ref=v7";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs@{
      self,
      home-manager,
      flake-parts,
      nix-ai-tools,
      nix-ai,
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

      flake.homeManagerModules.default = { lib, ... }: {
        # Imported here, not from ./modules: nix-ai is a flake argument, and
        # referencing _module.args from a module's imports recurses forever
        # (imports evaluate before args are wired — same reason nix-ai imports
        # nix-claude-code's schema module at its own flake level).
        imports = [
          ./modules
          nix-ai.homeManagerModules.opencode
        ];
        _module.args = {
          awesome-claude-skills = lib.mkDefault nix-ai.inputs.awesome-claude-skills;
          inherit nix-ai-tools;
        };
      };

      perSystem =
        { pkgs, system, ... }:
        let
          aiPackages = nix-ai-tools.packages.${system};
        in
        {
          packages = {
            inherit (aiPackages) crush mimo-code;

            # Goose is intentionally a Homebrew-only exception: its Nix package
            # rebuilds a large Rust test graph in the MacBook Home Manager closure.
            # This flake configures the existing block-goose-cli installation but
            # must never re-export or install a second Nix-managed Goose binary.
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
