{
  description = "Build environment for out-of-tree Siano driver patches";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # applying the patches
          patch
          git

          # building the kernel and modules
          # (requirements from Documentation/process/changes.rst)
          gnumake
          gcc
          flex
          bison
          bc
          perl
          openssl
          elfutils # libelf, used by objtool
          pkg-config
          pahole # needed when CONFIG_DEBUG_INFO_BTF is set
          python3
        ];
      };
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
