{
  description = "Patched Siano SMS1xxx DVB driver as a NixOS kernel module package, plus its build environment";

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
    # Adds a `siano` kernel module package to every linuxPackages set
    # (linuxPackages, linuxPackages_latest, ...), so it always builds against
    # the kernel the user actually runs.
    overlays.default = final: prev: {
      kernelPackagesExtensions =
        prev.kernelPackagesExtensions
        ++ [
          (kfinal: kprev: {
            siano = kfinal.callPackage ./kernel-module { };
          })
        ];
    };

    # Import this module — see README.md.  It applies the overlay above and
    # installs the patched modules, which override the stock in-tree ones.
    nixosModules.default = {
      config,
      ...
    }: {
      nixpkgs.overlays = [self.overlays.default];
      boot.extraModulePackages = [config.boot.kernelPackages.siano];
    };

    # Convenience / CI: build the modules against the default kernel of this
    # flake's nixpkgs (linux_6_18 at the time of writing).
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
    in {
      default = pkgs.linuxPackages.siano;
    });

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
