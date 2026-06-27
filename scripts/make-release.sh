#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIBVIRT_TAG=$1

gh release create $NIXOS_LIBVIRT_TAG \
  --title "Release $NIXOS_LIBVIRT_TAG" \
  --notes "Pending release" \
  --prerelease
