{
  description = "roc-playwright";

  nixConfig = {
    extra-substituters = [ "https://niclas-ahden.cachix.org" ];
    extra-trusted-public-keys = [ "niclas-ahden.cachix.org-1:FdGli1vBk0cTuVJV27Tau/JvlbW+Ly3pRwFByyqdke0=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Roc compiler revision, keep the `?dir=src` at the end.
    roc-src.url = "github:roc-lang/roc/756a5c201505f08d36cf1f5174f847a300338fa8?dir=src";
    roc-nix = {
      url = "github:niclas-ahden/roc-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.roc-src.follows = "roc-src";
    };
  };

  outputs = { nixpkgs, flake-utils, roc-nix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Builds Roc using `ReleaseFast`. To chase a suspected compiler fault,
        # build a `ReleaseSafe` variant of the same revision:
        #
        #   roc-nix.lib.${system}.mkRoc { optimize = "ReleaseSafe"; }
        #
        # roc-nix's README lists the rest of the build options, patches
        # included.
        roc = roc-nix.packages.${system}.roc;
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        packages = {
          inherit roc;
          default = roc;
        };

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              roc
              pkgs.playwright-test
              # The test servers (tests/server/main.mjs) run on node.
              pkgs.nodejs
            ];

            shellHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
          };
        };
      });
}
