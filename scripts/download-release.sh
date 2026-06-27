#!/bin/sh
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi
NIXOS_LIBVIRT_TAG=$1

gh release download --repo fr33m0nk/nixos-libvirt -D tmp --pattern "*.qcow2" $NIXOS_LIBVIRT_TAG
