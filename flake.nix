{
  description = "bash-uptime dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShell = pkgs.mkShell {
        name = "bash-uptime";
        buildInputs = with pkgs; [
          bash
          coreutils
          curl
          gnugrep
          gnused
          netcat-gnu
        ];
      };
      formatter = pkgs.alejandra;
    });
}
