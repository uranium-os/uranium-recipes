{ pkgs ? import /rod/nixpkgs { } }:

pkgs.rustPlatform.buildRustPackage {
  pname = "uranium-tools";
  version = "0.1.0";
  src = pkgs.lib.cleanSourceWith {
    src = ./uranium-tools;
    filter = p: _: baseNameOf p != "target";
  };
  preBuild = "export HOME=$TMPDIR";
  cargoLock.lockFile = ./uranium-tools/Cargo.lock;
  meta.license = pkgs.lib.licenses.cc0;
}
