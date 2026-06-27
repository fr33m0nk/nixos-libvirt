#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIBVIRT_TAG=$1
RUN_ID=$(gh run list --workflow "Build NixOS Libvirt Image" --branch master --limit 5 --json databaseId,headBranch,status --jq ".[] | select(.headBranch==\"$NIXOS_LIBVIRT_TAG\" or .headBranch==\"master\") | .databaseId" | head -1)
if [ -z "$RUN_ID" ]; then
  echo "ERROR: No CI run found for tag/branch $NIXOS_LIBVIRT_TAG. Push the tag first to trigger a build."
  exit 1
fi
echo "Using run ID: $RUN_ID"
IMAGEDIR=release-$NIXOS_LIBVIRT_TAG-images
mkdir -p $IMAGEDIR
echo Downloading nixos-libvirt-unstable-aarch64...
gh run download $RUN_ID --name nixos-libvirt-unstable-aarch64 --dir $IMAGEDIR
echo Downloading nixos-libvirt-unstable-x86_64...
gh run download $RUN_ID --name nixos-libvirt-unstable-x86_64  --dir $IMAGEDIR
mv $IMAGEDIR/nixos-libvirt-unstable-aarch64.qcow2 $IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-aarch64.qcow2
mv $IMAGEDIR/nixos-libvirt-unstable-x86_64.qcow2 $IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-x86_64.qcow2
