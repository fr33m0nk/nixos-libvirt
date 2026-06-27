#!/bin/sh
set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi

REPO="${REPO:-fr33m0nk/nixos-libvirt}"
NIXOS_LIBVIRT_TAG=$1
IMAGEDIR=release-$NIXOS_LIBVIRT_TAG-images

echo "Uploading to $REPO release $NIXOS_LIBVIRT_TAG..."
for ARCH in aarch64 x86_64; do
  FILE="$IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-$ARCH.qcow2"
  if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run download-tagged-artifacts.sh first."
    exit 1
  fi
  echo "  Uploading $FILE ($(du -h "$FILE" | cut -f1))..."
  gh release upload "$NIXOS_LIBVIRT_TAG" "$FILE" --repo "$REPO" --clobber
done
echo "Done."
