{ pkgs ? import /rod/nixpkgs { } }:

let
  bb = "${pkgs.busybox}/bin/busybox";
  applets = [ "sh" "mount" "umount" "findfs" "switch_root" "stat" "date" "mkdir" "mv" "rm" "rmdir" "cat" "sleep" "dirname" "ls" "tr" "cut" "head" "mountpoint" "grep" "sync" "losetup" "sed" ];
  init = pkgs.writeScript "uranium-init" (builtins.readFile ./uranium-init.sh);
  initrd = pkgs.makeInitrdNG {
    name = "uranium-initrd";
    compressor = "gzip";
    contents = [
      { source = init; target = "/init"; }
      { source = "${pkgs.btrfs-progs}/bin/btrfs"; target = "/bin/btrfs"; }
      { source = "${pkgs.cryptsetup}/bin/cryptsetup"; target = "/bin/cryptsetup"; }
    ] ++ map (a: { source = bb; target = "/bin/${a}"; }) applets;
  };
in
pkgs.runCommand "initramfs-uranium" { } ''
  install -Dm644 ${initrd}/initrd $out/boot/initrd
''
