#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIBVIRT_TAG=$1
JOBID=$(gh run list --branch $NIXOS_LIBVIRT_TAG --limit 1 --json databaseId | jq '.[0].databaseId')
IMAGEDIR=release-$NIXOS_LIBVIRT_TAG-images
mkdir -p $IMAGEDIR
echo Downloading nixos-libvirt-unstable-aarch64...
gh run download $RUN_ID --name nixos-libvirt-unstable-aarch64 --dir $IMAGEDIR
echo Downloading nixos-libvirt-unstable-x86_64...
gh run download $RUN_ID --name nixos-libvirt-unstable-x86_64  --dir $IMAGEDIR
mv $IMAGEDIR/nixos-libvirt-unstable-aarch64.qcow2 $IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-aarch64.qcow2
mv $IMAGEDIR/nixos-libvirt-unstable-x86_64.qcow2 $IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-x86_64.qcow2
