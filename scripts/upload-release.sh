#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIBVIRT_TAG=$1
IMAGEDIR=release-$NIXOS_LIBVIRT_TAG-images
RELEASE_FILES="$IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-aarch64.qcow2 $IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-x86_64.qcow2"
echo Uploading $RELEASE_FILES
gh release upload $NIXOS_LIBVIRT_TAG $RELEASE_FILES
