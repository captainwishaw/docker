#!/usr/bin/env bash
# Build a Arch Linux BAse image for Docker
# Based on https://raw.githubusercontent.com/docker/docker/master/contrib/mkimage-arch.sh

printf "Start to build Arch Linux Base image for Docker...\n"

if [ “$(id -u)” != “0” ]; then
printf "This script must be run as root\n"
exit 1
fi

# Use hash to test if the command is available
hash pacstrap &>/dev/null || {
    printf "Could not find pacstrap. Run pacman -S arch-install-scripts"
	exit 1
}

hash expect &>/dev/null || {
	printf "Could not find expect. Run pacman -S expect"
	exit 1
}

# Set the language as UTF-8
export LANG="C.UTF-8"

# Create a temp root file directory
ROOTFS=$(mktemp -d /tmp/rootfs-archlinux-XXXXXXXXXX)
printf "%s""\nTemp root directory: $ROOTFS \n"

# Set permissions
chmod 755 "$ROOTFS"

# Define the packages to not install for minimal image
PKGIGNORE=(
    cryptsetup
    device-mapper
    dhcpcd
    iproute2
    jfsutils
    linux
    lvm2
    man-db
    man-pages
    mdadm
    nano
    netctl
    openresolv
    pciutils
    pcmciautils
    reiserfsprogs
    s-nail
    systemd-sysvcompat
    usbutils
    vi
    xfsprogs
)

# Expand array with commas
IFS=','
PKGIGNORE="${PKGIGNORE[*]}"
unset IFS
printf "%s""\nPackages not to be installed : $PKGIGNORE\n \n"

# Set pacman.conf to provided conf file
PACMAN_CONF='./arch-docker-pacman.conf'


# Define the mirror for pacman
PACMAN_MIRRORLIST='Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch'

# Set basic variables to create image
PACMAN_EXTRA_PKGS=''
EXPECT_TIMEOUT=60
ARCH_KEYRING=archlinux
DOCKER_IMAGE_NAME=archlinux

# Export pacman mirror
export PACMAN_MIRRORLIST

expect <<EOF
	set send_slow {1 .1}
	proc send {ignore arg} {
		sleep .1
		exp_send -s -- \$arg
	}
	set timeout $EXPECT_TIMEOUT

	 spawn pacstrap -C $PACMAN_CONF -c -d -G -i $ROOTFS base haveged $PACMAN_EXTRA_PKGS --ignore $PKGIGNORE
	expect {
		-exact "anyway? \[Y/n\] " { send -- "n\r"; exp_continue }
		-exact "(default=all): " { send -- "\r"; exp_continue }
		-exact "installation? \[Y/n\]" { send -- "y\r"; exp_continue }
	}
EOF

# Remove manual files to save space
arch-chroot "$ROOTFS" /bin/sh -c 'rm -r /usr/share/man/*'

# Use haveged to generate random numbers and feed linux random device
# You must run `pacman-key --init` before first using pacman; the local
# keyring can then be populated with the keys of all official Arch Linux
# packagers with `pacman-key --populate archlinux`.

arch-chroot "$ROOTFS" /bin/sh -c "haveged -w 1024; pacman-key --init; pkill haveged; pacman -Rs --noconfirm haveged; pacman-key --populate $ARCH_KEYRING; pkill gpg-agent"

# Set local timezone to UTC
arch-chroot "$ROOTFS" /bin/sh -c "ln -s /usr/share/zoneinfo/UTC /etc/localtime"

# Set locale to 'en_US.UTF-8 UTF-8'
echo 'en_US.UTF-8 UTF-8' > "$ROOTFS"/etc/locale.gen
arch-chroot "$ROOTFS" locale-gen

# Set pacman mirrorlist
arch-chroot "$ROOTFS" /bin/sh -c "echo $PACMAN_MIRRORLIST > /etc/pacman.d/mirrorlist"

# udev doesn't work in containers, rebuild /dev
DEV=$ROOTFS/dev
rm -rf "$DEV"
mkdir -p "$DEV"
mknod -m 666 "$DEV"/null c 1 3
mknod -m 666 "$DEV"/zero c 1 5
mknod -m 666 "$DEV"/random c 1 8
mknod -m 666 "$DEV"/urandom c 1 9
mkdir -m 755 "$DEV"/pts
mkdir -m 1777 "$DEV"/shm
mknod -m 666 "$DEV"/tty c 5 0
mknod -m 600 "$DEV"/console c 5 1
mknod -m 666 "$DEV"/tty0 c 4 0
mknod -m 666 "$DEV"/full c 1 7
mknod -m 600 "$DEV"/initctl p
mknod -m 666 "$DEV"/ptmx c 5 2
ln -sf /proc/self/fd "$DEV"/fd

tar --numeric-owner --xattrs --acls -C "$ROOTFS" -c . | docker import - "$DOCKER_IMAGE_NAME"

# Test new image
docker run --rm -t $DOCKER_IMAGE_NAME echo Success

# Delete temp root file system
rm -rf "$ROOTFS"
