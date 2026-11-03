# uranium-recipes

Nix expressions for packages that are not in the nixpkgs index UraniumOS pins. rod checks `/rod/recipes` for a file with the package's name before it looks in the index.

| Recipe | Content |
| --- | --- |
| `linux-uranium.nix`, `linux-uranium.config` | kernel, built from mainline with this config |
| `initramfs-uranium.nix`, `uranium-init.sh` | initramfs and its init script |
| `doas-uranium.nix` | doas |
| `uranium-tools.nix` | the tools from `uranium-tools` |
| `avtty.nix`, `zen.nix`, `zoneinfo.nix` | programs and data |

`uranium-tools.nix` expects the source in a `uranium-tools` directory next to it; `uranium-mklive` puts it there when it builds an image. Handbook: https://uranium-os.github.io
