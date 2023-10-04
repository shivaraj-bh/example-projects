{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs@{ self, flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    # package doesn't work for all the systems yet
    systems = import inputs.systems;
    perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        cargoToml = builtins.fromTOML (builtins.readFile (self + /dog-app/Cargo.toml));
        inherit (cargoToml.package) name version;
        craneLib = inputs.crane.lib.${system};

        # Crane builder for cargo-leptos projects
        craneBuild = rec {
          args = {
            src = self + /dog-app;
            pname = name;
            version = version;
            buildInputs = with pkgs;[
              darwin.apple_sdk.frameworks.WebKit
              darwin.libiconv
              dioxus-cli
            ];
          };
          cargoArtifacts = craneLib.buildDepsOnly args;
          buildArgs = args // {
            inherit cargoArtifacts;
            buildPhaseCargoCommand = ''cargo build --release'';
            nativeBuildInputs = [
              pkgs.makeWrapper
            ];
            installPhaseCommand = ''
              mkdir -p $out/bin
              cp target/release/dog-app $out/bin/
            '';
          };
          package = craneLib.buildPackage buildArgs;
        };
      in
      {
        packages.dog-app = craneBuild.package;
      };
  };
}
