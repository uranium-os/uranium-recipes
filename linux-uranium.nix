{ pkgs ? import /rod/nixpkgs { } }:

let
  base = pkgs.linux_latest;
in
pkgs.stdenv.mkDerivation {
  pname = "linux-uranium";
  inherit (base) version src;

  nativeBuildInputs = with pkgs; [ bc bison flex perl openssl elfutils ];
  buildInputs = with pkgs; [ openssl elfutils ];
  hardeningDisable = [ "all" ];
  enableParallelBuilding = true;

  configurePhase = ''
    runHook preConfigure
    make defconfig
    scripts/kconfig/merge_config.sh -m .config ${./linux-uranium.config}
    make olddefconfig
    runHook postConfigure
  '';
  buildPhase = ''
    make -j$NIX_BUILD_CORES bzImage
  '';
  installPhase = ''
    install -Dm644 arch/x86/boot/bzImage $out/boot/vmlinuz
    install -Dm644 .config $out/boot/config
  '';
  dontStrip = true;
  dontFixup = true;
  meta.license = pkgs.lib.licenses.gpl2Only;
}
