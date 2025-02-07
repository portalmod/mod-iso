#!/bin/bash

set -e

TITLE="Live-MOD_2015.08-alpha1"

# Debian fix
export PATH=/usr/sbin/:$PATH

# ------------------------------------------------------------------------------------
# function to run a command inside the chroot

function run_chroot_cmd() {

echo "
export HOME=/root
export LANG=C
unset LC_TIME
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
$@
" | sudo tee ~/livecd/custom/_cmd >/dev/null

sudo chroot ~/livecd/custom /bin/bash /_cmd

}

# -------------------------------------------------------------------------------------------
# Check dependencies

if (which 7z > /dev/null); then true; else
  echo "7z not found, please install it"
  exit
fi

if (which cpio > /dev/null); then true; else
  echo "cpio not found, please install it"
  exit
fi

if (which debootstrap > /dev/null); then true; else
  echo "debootstrap not found, please install it"
  exit
fi

if (which gzip > /dev/null); then true; else
  echo "gzip not found, please install it"
  exit
fi

if (which lzma > /dev/null); then true; else
  echo "lzma not found, please install it"
  exit
fi

if (which mksquashfs > /dev/null); then true; else
  echo "mksquashfs not found, please install it"
  exit
fi

if (which xorriso > /dev/null); then true; else
  echo "xorriso not found, please install it"
  exit
fi

# -------------------------------------------------------------------------------------------
# start bootstrap

if [ ! -d ~/livecd/custom/var/mod-live ]; then
  sudo mkdir -p ~/livecd
  sudo debootstrap --arch=amd64 xenial ~/livecd/custom http://archive.ubuntu.com/ubuntu/
  sudo mkdir ~/livecd/custom/var/mod-live
fi

# -------------------------------------------------------------------------------------------
# we need this for later

if [ ! -f ~/livecd/iso-stuff.7z ]; then
  echo "Please copy iso-stuff.7z to ~/livecd before continuing"
  exit
fi

# -------------------------------------------------------------------------------------------
# enable network

sudo rm -f ~/livecd/custom/etc/hosts
sudo rm -f ~/livecd/custom/etc/resolv.conf
sudo cp /etc/resolv.conf /etc/hosts ~/livecd/custom/etc/

# ------------------------------------------------------------------------------------
# mount basic chroot points

run_chroot_cmd mount -t devpts none /dev/pts || true
run_chroot_cmd mount -t proc   none /proc    || true
run_chroot_cmd mount -t sysfs  none /sys     || true

# ------------------------------------------------------------------------------------
# proper xenial repos + backports

if [ ! -f ~/livecd/custom/var/mod-live/initial-setup-1 ]; then
  echo "
deb http://archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu xenial-security main restricted universe multiverse
" | sudo tee ~/livecd/custom/etc/apt/sources.list >/dev/null
  sudo touch ~/livecd/custom/var/mod-live/initial-setup-1
fi

# ------------------------------------------------------------------------------------
# install kxstudio-repos package

if [ ! -f ~/livecd/custom/var/mod-live/initial-setup-2 ]; then
  run_chroot_cmd apt-get update || true
  run_chroot_cmd apt-get install --no-install-recommends -y software-properties-common wget apt-transport-https libglibmm-2.4-1v5
  run_chroot_cmd wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_9.4.1%7Ekxstudio1_all.deb
  run_chroot_cmd wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos-gcc5_9.4.1%7Ekxstudio1_all.deb
  run_chroot_cmd dpkg -i *.deb
  run_chroot_cmd rm *.deb
  run_chroot_cmd add-apt-repository ppa:kxstudio-debian/kxstudio-mod -y
  sudo touch ~/livecd/custom/var/mod-live/initial-setup-2
fi

# ------------------------------------------------------------------------------------
# do a full system update

run_chroot_cmd apt-get update || true
run_chroot_cmd apt-get dist-upgrade -y

# -------------------------------------------------------------------------------------------
# Base Install + kernel

if [ ! -f ~/livecd/custom/var/mod-live/initial-setup-3 ]; then
  run_chroot_cmd apt-get install --no-install-recommends -y ubuntu-standard laptop-detect
  sudo touch ~/livecd/custom/var/mod-live/initial-setup-3
fi

if [ ! -f ~/livecd/custom/var/mod-live/initial-setup-4 ]; then
  # skip grub install/configure to HDD here
  run_chroot_cmd apt-get install --no-install-recommends -y linux-lowlatency linux-image-lowlatency linux-headers-lowlatency
  sudo touch ~/livecd/custom/var/mod-live/initial-setup-4
fi

# -------------------------------------------------------------------------------------------
# Full install

run_chroot_cmd apt-get install --no-install-recommends -y kxstudio-meta-live-conflicts kxstudio-artwork \
    acpid alsa-base alsa-utils pm-utils xdg-utils xorg xserver-xorg-video-all \
    alsa-firmware linux-firmware linux-firmware-nonfree \
    casper lupin-casper consolekit dbus-x11 dmz-cursor-theme nano ufw jackd2 \
    libpam-systemd lightdm lightdm-gtk-greeter policykit-1 plymouth plymouth-label ttf-dejavu ttf-dejavu-extra \
    mod-artwork mod-app mod-iso mod-sdk mod-sdk-lv2 lv2-dev \
    mod-distortion mod-mda-lv2 mod-pitchshifter mod-utilities \
    artyfx blop-lv2 caps-lv2 fomp sooperlooper-lv2 swh-lv2 tap-lv2 \
    dpf-plugins guitarix gxvoxtonebender setbfree \
    kxstudio-default-settings patchage jaaa japa \
    alsa-tools libpam-ck-connector libtxc-dxtn-s2tc0 xfonts-scalable xserver-xorg-video-intel xserver-xorg-video-qxl
# python3-lilv

# -------------------------------------------------------------------------------------------
# Install local packages, if any

if [ -f local-pkgs/*.deb ]; then
    sudo mkdir ~/livecd/custom/pkgs
    sudo cp local-pkgs/*.deb ~/livecd/custom/pkgs/
    run_chroot_cmd dpkg -i /pkgs/*.deb
    sudo rm -r ~/livecd/custom/pkgs
fi

# -------------------------------------------------------------------------------------------
# Remove unneeded packages

run_chroot_cmd apt-get autoremove
run_chroot_cmd apt-get clean

# -------------------------------------------------------------------------------------------
# Cleanup

# run_chroot_cmd /usr/bin/updatedb.mlocate

sudo rm -f ~/livecd/custom/etc/hosts
sudo rm -f ~/livecd/custom/etc/resolv.conf
sudo rm -f ~/livecd/custom/var/kxstudio/*
sudo rm -rf ~/livecd/custom/tmp/*

run_chroot_cmd ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
# run_chroot_cmd find /var/log -type f | while read file; do cat /dev/null | tee $file; done
run_chroot_cmd umount /dev/pts
run_chroot_cmd umount -lf /proc
run_chroot_cmd umount /sys

sudo rm -f ~/livecd/custom/_cmd

# -------------------------------------------------------------------------------------------
# Create squashfs file

sudo mkdir -p ~/livecd/cd/casper/
cd ~/livecd/cd/casper/
sudo rm -f ./filesystem.squashfs
sudo touch ./filesystem.manifest
sudo touch ./filesystem.size
sudo chmod 777 ./filesystem.manifest
sudo chmod 777 ./filesystem.size
sudo chroot ~/livecd/custom dpkg-query -W --showformat='${Package} ${Version}\n' > ./filesystem.manifest
sudo su root -c "printf $(sudo du -sx --block-size=1 ~/livecd/custom | cut -f1) > ./filesystem.size"
sudo mksquashfs ~/livecd/custom ./filesystem.squashfs -noappend -comp xz

# -------------------------------------------------------------------------------------------
# Create ISO artwork

if [ ! -f ~/livecd/cd/.disk/info ]; then
  sudo mkdir -p ~/livecd/cd
  cd ~/livecd/cd

  sudo 7z x -y ../iso-stuff.7z

  sudo mkdir -p .disk
  sudo su root -c 'echo "${TITLE}" > .disk/info'
  #sudo su root -c 'echo "http://moddevices.com/" > .disk/release_notes_url'
fi

# -------------------------------------------------------------------------------------------
# Create boot image

cd ~/livecd/
sudo rm -f cd/casper/vmlinuz cd/casper/vmlinuz.efi cd/casper/initrd.lz cd/casper/initrd_tmp.gz
sudo cp custom/boot/vmlinuz-* cd/casper/vmlinuz
sudo cp custom/boot/vmlinuz-* cd/casper/vmlinuz.efi
sudo cp custom/boot/initrd.img-* cd/casper/initrd_tmp.gz

cd ~/livecd/cd/casper
sudo rm -rf ext
sudo mkdir ext
cd ext
sudo su root -c 'gzip -cd ../initrd_tmp.gz | cpio -i'

# fix links
LINKS=`find . -type l`
for i in $LINKS; do
  FILE=`readlink $i`
  if [ "$FILE" == "busybox" ]; then
    FILE="./bin/busybox"
  elif [ "$FILE" == "lvm" ]; then
    FILE="./sbin/lvm"
  fi
  sudo rm "$i"
  if [ -f "./$FILE" ]; then
    sudo cp -v "./$FILE" "$i"
  else
    sudo cp -v "../../../custom/$FILE" "$i" || true
  fi
done

sudo su root -c 'find . | cpio --dereference -o -H newc | lzma -7 > ../initrd.lz'
cd ..
sudo rm -rf ext initrd_tmp.gz

# -------------------------------------------------------------------------------------------
# Create ISO file

cd ~/livecd/cd

sudo xorriso -as mkisofs \
    -r \
    -V "${TITLE}" \
    -o ~/livecd/${TITLE}.iso \
    -J \
    -isohybrid-mbr isolinux/isohdpfx.bin \
    -partition_offset 16 \
    -joliet-long \
    -cache-inodes \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    .

# -------------------------------------------------------------------------------------------
