#!/bin/bash

set -e

# check for root permissions
if [[ "$(id -u)" != 0 ]]; then
  echo "E: Requires root permissions" > /dev/stderr
  exit 1
fi

# get config
if [ -n "$1" ]; then
  CONFIG_FILE="$1"
else
  CONFIG_FILE="etc/terraform.conf"
fi
BASE_DIR="$PWD"
source "$BASE_DIR"/"$CONFIG_FILE"

echo -e "
#----------------------#
# INSTALL DEPENDENCIES #
#----------------------#
"

apt-get update
apt-get install -y live-build patch binutils zstd
dpkg -i ./debs/*.deb
patch /usr/lib/live/build/binary_grub-efi < live-build-fix-shim-remove.patch

ln -sfn /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/impish

build () {
  BUILD_ARCH="$1"

  mkdir -p "$BASE_DIR/tmp/$BUILD_ARCH"
  cd "$BASE_DIR/tmp/$BUILD_ARCH" || exit

  # remove old configs and copy over new
  rm -rf config auto
  cp -r "$BASE_DIR"/etc/* .
  # Make sure conffile specified as arg has correct name
  cp -f "$BASE_DIR"/"$CONFIG_FILE" terraform.conf

  # Symlink chosen package lists to where live-build will find them
  ln -s "package-lists.$PACKAGE_LISTS_SUFFIX" "config/package-lists"

  echo -e "
#------------------#
# LIVE-BUILD CLEAN #
#------------------#
"
  lb clean

  echo -e "
#-------------------#
# LIVE-BUILD CONFIG #
#-------------------#
"
  lb config

  echo -e "
#------------------#
# LIVE-BUILD BUILD #
#------------------#
"
  lb build

  echo -e "
#---------------------------#
# MOVE OUTPUT TO BUILDS DIR #
#---------------------------#
"

    YYYYMMDD="$(date +%Y%m%d%H%M)"
    OUTPUT_DIR="$BASE_DIR/builds/$BUILD_ARCH"
    mkdir -p "$OUTPUT_DIR"
    FNAME="ubuntudde-$VERSION-$BUILD_ARCH-$YYYYMMDD-$OUTPUT_SUFFIX"
    mv "$BASE_DIR/tmp/$BUILD_ARCH/live-image-$BUILD_ARCH.hybrid.iso" "$OUTPUT_DIR/${FNAME}.iso"

    md5sum "$OUTPUT_DIR/${FNAME}.iso" > "$OUTPUT_DIR/${FNAME}.md5.txt"
    sha256sum "$OUTPUT_DIR/${FNAME}.iso" > "$OUTPUT_DIR/${FNAME}.sha256.txt"
}

# remove old builds before creating new ones
rm -rf "$BASE_DIR"/builds

build "$ARCH"

