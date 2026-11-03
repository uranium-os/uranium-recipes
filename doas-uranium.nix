{ pkgs ? import /rod/nixpkgs { } }:

pkgs.doas.override { withPAM = false; withTimestamp = true; }
