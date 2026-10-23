# Out-of-tree Linux patches for Siano driver

Out-of-tree patches for the Siano SMS1xxx driver
(`drivers/media/common/siano` and `drivers/media/usb/siano`), applied on
top of a vanilla kernel release. Verified against linux-6.18.58: the four
patches below apply cleanly in this order, and the Siano modules
(`smsmdtv.ko`, `smsdvb.ko`, `smsusb.ko`) build.

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

## Applying

Kernel sources are expected under `misc/` (git-ignored). Extract the
vanilla tarball there, apply the patches, then build inside the tree:

    tar -xJf linux-6.18.58.tar.xz -C misc
    cd misc/linux-6.18.58
    for p in /path/to/this/repo/*.patch; do patch -p1 < "$p"; done

## Building

The build environment is managed by the Nix flake (`nix develop`, or
direnv via `.envrc`):

    make defconfig
    scripts/config --module MEDIA_SUPPORT --enable MEDIA_USB_SUPPORT \
        --enable MEDIA_DIGITAL_TV_SUPPORT --module DVB_CORE --module SMS_USB_DRV
    make olddefconfig
    make -j"$(nproc)" vmlinux modules_prepare modules

The Siano modules are built as
`drivers/media/common/siano/{smsmdtv,smsdvb}.ko` and
`drivers/media/usb/siano/smsusb.ko`.
