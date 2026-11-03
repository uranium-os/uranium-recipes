{ pkgs ? import /rod/nixpkgs { } }:

pkgs.stdenv.mkDerivation {
  pname = "zen";
  version = "1.24b";
  src = pkgs.fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/1.24b/zen.linux-x86_64.tar.xz";
    sha256 = "323f2682e73e38247a51fbcc75e5628ed2bb9b404db00cf9cf16af329a916fae";
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
  buildInputs = with pkgs; [ gtk3 glib dbus-glib alsa-lib libxkbcommon libGL pciutils xorg.libX11 xorg.libXcomposite xorg.libXdamage xorg.libXext xorg.libXfixes xorg.libXrandr xorg.libxcb libgbm stdenv.cc.cc.lib ];
  runtimeDependencies = with pkgs; [ gtk3 libGL libxkbcommon wayland pciutils ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/lib/zen $out/bin
    cp -r . $out/lib/zen
    makeWrapper $out/lib/zen/zen $out/bin/zen --set MOZ_ENABLE_WAYLAND 1
  '';
  meta.license = pkgs.lib.licenses.mpl20;
}
