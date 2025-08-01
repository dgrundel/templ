{
  description = "templ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    version = {
      url = "github:a-h/version/0.0.10";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xc = {
      url = "github:joerdav/xc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, gitignore, version, xc }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        inherit system;
        pkgs =
          let
            pkgs-unstable = import nixpkgs-unstable { inherit system; };
          in
          import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                gopls = pkgs-unstable.gopls;
                version = version.packages.${system}.default; # Used to apply version numbers to the repo.
                xc = xc.packages.${system}.xc;
              })
            ];
          };
      });
    in
    {
      packages = forAllSystems ({ pkgs, ... }:
        rec {
          default = templ;

          templ = pkgs.buildGo124Module {
            name = "templ";
            subPackages = [ "cmd/templ" ];
            src = gitignore.lib.gitignoreSource ./.;
            vendorHash = "sha256-eJV0q+qG1QETydYtE6hipuxyp+P649RzF36Jc4qe8e4=";
            env = {
              CGO_ENABLED = 0;
            };
            flags = [
              "-trimpath"
            ];
            ldflags = [
              "-s"
              "-w"
              "-extldflags -static"
            ];
          };
        });

      # `nix develop` provides a shell containing development tools.
      devShell = forAllSystems ({ pkgs, ... }:
        pkgs.mkShell {
          buildInputs = [
            pkgs.golangci-lint
            pkgs.cosign # Used to sign container images.
            pkgs.esbuild # Used to package JS examples.
            pkgs.go
            pkgs.gopls
            pkgs.goreleaser
            pkgs.gotestsum
            pkgs.ko # Used to build Docker images.
            pkgs.nodejs # Used to build templ-docs.
            pkgs.version
            pkgs.xc
          ];
        });

      # This flake outputs an overlay that can be used to add templ and
      # templ-docs to nixpkgs as per https://templ.guide/quick-start/installation/#nix
      #
      # Example usage:
      #
      # nixpkgs.overlays = [
      #   inputs.templ.overlays.default
      # ];
      overlays.default = final: prev: {
        templ = self.packages.${final.stdenv.system}.templ;
        templ-docs = self.packages.${final.stdenv.system}.templ-docs;
      };
    };
}

