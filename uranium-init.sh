#!/bin/sh
# uranium initramfs
export PATH=/bin

mkdir -p /proc /sys /dev /run /tmp /top /newroot
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

root= frame= want_shell= luks= lkey= live= init=/rod/init/bin/init
for x in $(cat /proc/cmdline); do
    case $x in
        root=*) root=${x#root=} ;;
        init=*) init=${x#init=} ;;
        uranium.frame=*) frame=${x#uranium.frame=} ;;
        uranium.shell) want_shell=1 ;;
        uranium.live) live=1 ;;
        uranium.luks=*) luks=${x#uranium.luks=} ;;
        uranium.luks.key=*) lkey=${x#uranium.luks.key=} ;;
    esac
done

fail() { echo "initramfs: $*"; echo "dropping to a shell"; exec sh; }

[ -n "$want_shell" ] && { echo "initramfs shell, exit to continue"; sh; }

# live medium
if [ -n "$live" ]; then
    mkdir -p /iso /ro /rw
    found=; i=0
    while [ $i -lt 60 ] && [ -z "$found" ]; do
        for d in /dev/sr* /dev/vd* /dev/sd* /dev/nvme*n*; do
            [ -b "$d" ] || continue
            if mount -t iso9660 -o ro "$d" /iso 2> /dev/null; then
                if [ -f /iso/live/root.squashfs ]; then found=$d; break; fi
                umount /iso
            fi
        done
        [ -n "$found" ] || { sleep 0.5; i=$((i + 1)); }
    done
    [ -n "$found" ] || fail "no live medium"
    mount -t squashfs -o loop,ro /iso/live/root.squashfs /ro || fail "cannot mount the live image"
    mount -t tmpfs -o size=75% tmpfs /rw
    mkdir -p /rw/up /rw/work /newroot
    mount -t overlay overlay -o lowerdir=/ro,upperdir=/rw/up,workdir=/rw/work /newroot || fail "cannot mount the live root"
    mkdir -p /newroot/run/live/iso /newroot/run/live/ro
    mount --move /iso /newroot/run/live/iso
    mount --move /ro /newroot/run/live/ro
    umount /proc /sys /dev
    exec switch_root /newroot "$init"
fi

# unlock an encrypted root
if [ -n "$luks" ]; then
    ldev=; i=0
    while [ $i -lt 100 ] && [ -z "$ldev" ]; do
        case $luks in /dev/*) [ -b "$luks" ] && ldev=$luks ;; *) ldev=$(findfs "$luks" 2> /dev/null) ;; esac
        [ -n "$ldev" ] || { sleep 0.2; i=$((i + 1)); }
    done
    [ -n "$ldev" ] || fail "no encrypted device: $luks"
    if [ -n "$lkey" ]; then
        cryptsetup open --key-file "$lkey" "$ldev" uranium-root || fail "cannot unlock $ldev"
    else
        n=0
        until cryptsetup open "$ldev" uranium-root; do n=$((n + 1)); [ $n -ge 3 ] && fail "cannot unlock $ldev"; done
    fi
fi

# find the root device
dev=; i=0
while [ $i -lt 100 ]; do
    case $root in
        LABEL=*|UUID=*|PARTUUID=*|PARTLABEL=*) dev=$(findfs "$root" 2> /dev/null) ;;
        *) [ -b "$root" ] && dev=$root ;;
    esac
    [ -n "$dev" ] && break
    sleep 0.2; i=$((i + 1))
done
[ -n "$dev" ] || fail "no root device: $root"

mkdir -p /top /newroot
mount -t btrfs -o subvolid=5 "$dev" /top || fail "cannot mount $dev"
F=/top/.scram

isvol() { [ "$(stat -c %i "$1" 2> /dev/null)" = 256 ]; }

mkframe() {
    id=$(date +%Y%m%d-%H%M%S)-$1
    mkdir -p "$F/$id"
    for s in @ @home; do btrfs subvolume snapshot -r "/top/$s" "$F/$id/$s" > /dev/null; done
    echo "$id"
}

# replace subvolume
swap() {
    s=$1; new=$2
    if [ -f "$F/keep.list" ]; then
        while read -r ks inner; do
            [ "$ks" = "$s" ] || continue
            isvol "/top/$s/$inner" || continue
            rmdir "$new/$inner" 2> /dev/null
            mkdir -p "$(dirname "$new/$inner")"
            mv "/top/$s/$inner" "$new/$inner" || return 1
        done < "$F/keep.list"
    fi
    btrfs subvolume delete "/top/$s" > /dev/null || return 1
    mv "$new" "/top/$s"
}

# unconfirmed update
if [ -z "$frame" ] && [ -f "$F/trial" ]; then
    read -r tpre < "$F/trial"
    if [ -f "$F/trial-boot" ] && [ -d "$F/$tpre/@" ]; then
        pre=$(mkframe pre-revert)
        btrfs subvolume snapshot "$F/$tpre/@" "$F/.new-@" > /dev/null && swap @ "$F/.new-@" &&
            echo "update was not confirmed, reverted to frame $tpre, undo with frame $pre"
    fi
    rm -f "$F/trial" "$F/trial-boot"
fi

# pending commit or flash
if [ -f "$F/boot-action" ]; then
    read -r act arg only < "$F/boot-action"
    case $act in
        commit)
            if [ -d "$F/try/@" ]; then
                pre=$(mkframe pre-commit)
                swap @ "$F/try/@" && rm -rf "$F/try" && echo "$pre" > "$F/trial" && : > "$F/trial-boot" &&
                    echo "update committed on trial, undo with frame $pre"
            fi ;;
        flash)
            if [ -d "$F/$arg" ]; then
                pre=$(mkframe pre-flash)
                for s in ${only:-@ @home}; do
                    btrfs subvolume snapshot "$F/$arg/$s" "$F/.new-$s" > /dev/null && swap "$s" "$F/.new-$s"
                done
                echo "flashed to $arg, undo with frame $pre"
            fi ;;
    esac
    rm -f "$F/boot-action"
    sync
fi

# frame boot
rootsub=@ homesub=@home
if [ -n "$frame" ]; then
    mkdir -p "$F/live"
    for s in @ @home; do
        [ -d "$F/live/$s" ] && btrfs subvolume delete "$F/live/$s" > /dev/null
        btrfs subvolume snapshot "$F/$frame/$s" "$F/live/$s" > /dev/null || fail "cannot open frame $frame"
    done
    rootsub=.scram/live/@ homesub=.scram/live/@home
    echo "booting frame $frame, changes are dropped at the next frame boot"
fi

mount -t btrfs -o "subvol=$rootsub,noatime" "$dev" /newroot || fail "cannot mount the root subvolume"
if [ -n "$frame" ]; then
    mkdir -p /newroot/home
    mount -t btrfs -o "subvol=$homesub,noatime" "$dev" /newroot/home
fi
mkdir -p /newroot/run/scram/top
mount --move /top /newroot/run/scram/top

umount /proc /sys /dev
exec switch_root /newroot "$init"
