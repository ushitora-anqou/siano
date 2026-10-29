{
  lib,
  stdenv,
  kernel,
}:

# Rebuilds the in-tree Siano SMS1xxx driver (drivers/media/common/siano and
# drivers/media/usb/siano) with the patches from this repository applied,
# following the "Patching a single in-tree kernel module" recipe of
# https://wiki.nixos.org/wiki/Linux_kernel#Out-of-tree_kernel_modules
#
# Add the result to boot.extraModulePackages: because the modules carry the
# same names as the kernel's stock ones, they replace them in the system's
# module tree.
stdenv.mkDerivation {
  pname = "siano";
  version = "${kernel.version}-patched";

  # Reuse the kernel's source, nixpkgs kernel patches and postPatch so that
  # the tree we build against matches the one the kernel was built from.
  inherit (kernel) src postPatch;
  patches =
    kernel.patches
    ++ [
      ../media-siano-fix-oops-in-smsdvb_hotplug-due-to-race-condition.patch
      ../media-siano-validate-family2-firmware-extents.patch
      ../v2-media-siano-initialise-the-urb-work-once-not-on-every-completion.patch
      ../v3-media-usb-siano-don-t-set-URB_FREE_BUFFER-flag.patch
    ];

  nativeBuildInputs = kernel.nativeBuildInputs ++ kernel.moduleBuildDependencies;

  hardeningDisable = [
    "pic"
    "format"
  ];

  enableParallelBuilding = true;

  kernelDev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  # kernel.commonMakeFlags is kernelModuleMakeFlags minus KBUILD_OUTPUT: we
  # build in a prepared tree of our own, not in the kernel's build directory,
  # so KBUILD_OUTPUT must not leak in.  The flags carry the kernel's toolchain
  # selection, ARCH=, and the kmodigest cmd_sign override used by NixOS.
  makeFlags = kernel.commonMakeFlags;

  # Declaring makeFlags also exports it as a shell variable for the custom
  # phases below, which pass it to make themselves (the default phases would
  # pass it automatically, but cannot express our sequence of targets).
  buildPhase = ''
    runHook preBuild

    buildKernel=$kernelDev/lib/modules/$kernelVersion/build

    cp "$buildKernel/Module.symvers" .
    cp "$buildKernel/.config" .
    cp "$kernelDev/vmlinux" . # needed for module BTF

    if ! grep -q '^CONFIG_SMS_USB_DRV=m' .config; then
      echo 'ERROR: this kernel does not build the Siano driver as a module' >&2
      echo '       (.config lacks CONFIG_SMS_USB_DRV=m); there is nothing to package.' >&2
      exit 1
    fi

    # shellcheck disable=SC2086
    make $makeFlags -j"$NIX_BUILD_CORES" modules_prepare
    # shellcheck disable=SC2086
    make $makeFlags -j"$NIX_BUILD_CORES" M=drivers/media/common/siano modules
    # shellcheck disable=SC2086
    make $makeFlags -j"$NIX_BUILD_CORES" M=drivers/media/usb/siano modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # shellcheck disable=SC2086
    make $makeFlags M=drivers/media/common/siano modules_install INSTALL_MOD_PATH="$out"
    # shellcheck disable=SC2086
    make $makeFlags M=drivers/media/usb/siano modules_install INSTALL_MOD_PATH="$out"

    # Fail loudly instead of shipping an empty package.  (Use find rather
    # than a shell glob: stdenv sets nullglob, which would make an unmatched
    # glob disappear silently.)
    for mod in smsmdtv smsdvb smsusb; do
      if ! find "$out/lib/modules/$kernelVersion" -name "$mod.ko*" -print -quit | grep -q .; then
        echo "ERROR: $mod.ko was not built or installed" >&2
        exit 1
      fi
    done

    runHook postInstall
  '';

  meta = {
    description = "Siano SMS1xxx DVB driver (smsmdtv, smsdvb, smsusb) with fixes not yet merged upstream";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
