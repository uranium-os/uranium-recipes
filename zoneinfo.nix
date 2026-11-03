{ pkgs ? import /rod/nixpkgs { } }:

pkgs.runCommand "zoneinfo" { } ''
  mkdir -p $out/share
  ln -s ${pkgs.tzdata}/share/zoneinfo $out/share/zoneinfo
''
