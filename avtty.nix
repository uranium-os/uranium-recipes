{ pkgs ? import /rod/nixpkgs { } }:

pkgs.stdenv.mkDerivation {
  pname = "avtty";
  version = "0.12.0";
  src = pkgs.fetchurl {
    url = "https://github.com/texivi/avtty/archive/d4baa2f176a529d3f27b218a43bae51685df2c87.tar.gz";
    sha256 = "79262e08234c5ddd997e21fc00df13fecd336ec45af6ceab4493d2f819bb5a99";
  };
  buildPhase = "cc -O2 avtty.c -o avtty";
  installPhase = "install -Dm755 avtty $out/bin/avtty";
  meta.license = pkgs.lib.licenses.gpl3Only;
}
