# Out-of-tree Linux patches for Siano driver

Out-of-tree patches for the Siano SMS1xxx driver
(`drivers/media/common/siano` and `drivers/media/usb/siano`), applied on
top of a vanilla kernel release. Verified against linux-6.18.58: the four
patches below apply cleanly in this order, and the Siano modules
(`smsmdtv.ko`, `smsdvb.ko`, `smsusb.ko`) build.

The Nix flake in this repository packages the patched driver as a kernel
module package, so a NixOS system can use it with two lines of
configuration (see below).

## Patches

Applied in the order below (i.e. glob order):

1. [media: siano: fix oops in smsdvb_hotplug() due to race condition](https://lore.kernel.org/linux-media/20261018054403.76055-1-ryotaro.banno@gmail.com/)
   (`media-siano-fix-oops-in-smsdvb_hotplug-due-to-race-condition.patch`)
2. [media: siano: validate family2 firmware extents](https://lore.kernel.org/linux-media/20260830134011.8582-1-pengpeng@iscas.ac.cn/)
   (`media-siano-validate-family2-firmware-extents.patch`)
3. [media: siano: initialise the urb work once, not on every completion (v2)](https://lore.kernel.org/linux-media/20261007112257.1888-1-yogeshgaur.83@gmail.com/)
   (`v2-media-siano-initialise-the-urb-work-once-not-on-every-completion.patch`)
4. [media: usb: siano: don't set URB_FREE_BUFFER flag (v3)](https://lore.kernel.org/linux-media/09b616df-ea9f-4ea1-86be-ab600119f9ae@I-love.SAKURA.ne.jp/)
   (`v3-media-usb-siano-don-t-set-URB_FREE_BUFFER-flag.patch`)

## Usage on NixOS (flake)

The flake rebuilds the in-tree Siano modules with the patches applied,
following the [out-of-tree kernel module] recipe of the NixOS wiki, and
exposes them as `config.boot.kernelPackages.siano`. Because the packaged
modules carry the same names as the kernel's stock ones, adding the package
to `boot.extraModulePackages` *replaces* the stock modules in the system's
module tree — no full kernel rebuild needed.

[out-of-tree kernel module]: https://wiki.nixos.org/wiki/Linux_kernel#Out-of-tree_kernel_modules

Add the flake to your system and import its NixOS module:

```nix
# your flake.nix
{
  inputs.siano.url = "github:ushitora-anqou/siano";

  outputs = {nixpkgs, siano, ...}: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        {nixpkgs.hostPlatform = "x86_64-linux";}
        ./configuration.nix
        siano.nixosModules.default
      ];
    };
  };
}
```

That is all: the NixOS module applies the flake's overlay and adds the
patched modules to `boot.extraModulePackages` for the kernel you run.
The module ships USB device ID aliases, so udev loads it on hotplug.

The package is built per kernel: `config.boot.kernelPackages.siano`
always matches whatever `boot.kernelPackages` is set to. The patches
currently apply to linux-6.18.y; on other kernel lines (e.g.
`linuxPackages_latest`) the build fails at patch-application time, which
is intentional and loud.

To build the modules standalone against the default kernel of this
flake's nixpkgs (useful as a smoke test):

    nix build github:ushitora-anqou/siano

## Applying and building manually (development)

The sections below describe the manual, in-tree build used to develop and
verify the patches. The Nix build environment is managed by the flake
(`nix develop`, or direnv via `.envrc`).

Kernel sources are expected under `misc/` (git-ignored). Extract the
vanilla tarball there, apply the patches, then build inside the tree:

    tar -xJf linux-6.18.58.tar.xz -C misc
    cd misc/linux-6.18.58
    for p in /path/to/this/repo/*.patch; do patch -p1 < "$p"; done

Then build:

    make defconfig
    scripts/config --module MEDIA_SUPPORT --enable MEDIA_USB_SUPPORT \
        --enable MEDIA_DIGITAL_TV_SUPPORT --module DVB_CORE --module SMS_USB_DRV
    make olddefconfig
    make -j"$(nproc)" vmlinux modules_prepare modules

The Siano modules are built as
`drivers/media/common/siano/{smsmdtv,smsdvb}.ko` and
`drivers/media/usb/siano/smsusb.ko`.
