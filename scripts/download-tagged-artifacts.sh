#!/bin/sh
set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tag>"
  exit 1
fi

NIXOS_LIBVIRT_TAG="$1"
REPO="${REPO:-fr33m0nk/nixos-libvirt}"

# Find the CI run for this tag
RUN_ID=$(gh run list --repo "$REPO" --workflow "Build NixOS Libvirt Image" --limit 10 \
  --json databaseId,headBranch,status \
  --jq ".[] | select(.headBranch==\"$NIXOS_LIBVIRT_TAG\") | .databaseId" | head -1)

if [ -z "$RUN_ID" ]; then
  echo "ERROR: No CI run found for tag $NIXOS_LIBVIRT_TAG"
  exit 1
fi
echo "Using run ID: $RUN_ID"

IMAGEDIR="release-$NIXOS_LIBVIRT_TAG-images"
mkdir -p "$IMAGEDIR"

# Fetch artifact list once
echo "Fetching artifact list..."
ARTIFACTS_JSON=$(gh api "/repos/$REPO/actions/runs/$RUN_ID/artifacts")

download_artifact() {
  arch="$1"  # aarch64 or x86_64
  name="nixos-libvirt-unstable-$arch"

  ART_ID=$(echo "$ARTIFACTS_JSON" | jq -r ".artifacts[] | select(.name == \"$name\") | .id")
  if [ -z "$ART_ID" ] || [ "$ART_ID" = "null" ]; then
    echo "ERROR: artifact '$name' not found in run $RUN_ID"
    return 1
  fi

  ART_SIZE=$(echo "$ARTIFACTS_JSON" | jq -r ".artifacts[] | select(.name == \"$name\") | .size_in_bytes")
  ART_SIZE_MB=$(echo "scale=1; $ART_SIZE / 1048576" | bc)

  # Get signed download URL (GH API returns 302 redirect to blob storage)
  echo "[$arch] Resolving download URL..."
  DOWNLOAD_URL=$(gh api "/repos/$REPO/actions/artifacts/$ART_ID/zip" --method GET --include 2>/dev/null \
    | grep -i '^location:' | sed 's/^location: //i' | tr -d '\r')

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: could not resolve download URL for $name"
    return 1
  fi

  OUTFILE="$IMAGEDIR/${name}.zip"
  echo "[$arch] Downloading $name ($ART_SIZE_MB MB)..."

  # Start curl in background, then poll file size for progress
  START_TS=$(date +%s)
  curl -s -L -o "$OUTFILE" "$DOWNLOAD_URL" &
  CURL_PID=$!

  while kill -0 $CURL_PID 2>/dev/null; do
    sleep 2
    if [ -f "$OUTFILE" ]; then
      DL_BYTES=$(wc -c < "$OUTFILE" 2>/dev/null || echo 0)
      if [ "$ART_SIZE" -gt 0 ] 2>/dev/null; then
        DL_PCT=$(echo "scale=1; $DL_BYTES * 100 / $ART_SIZE" | bc)
      else
        DL_PCT="??"
      fi
      DL_MB=$(echo "scale=1; $DL_BYTES / 1048576" | bc)
      ELAPSED=$(($(date +%s) - START_TS))
      if [ "$ELAPSED" -gt 0 ] && [ "$DL_BYTES" -gt 0 ]; then
        SPEED_KB=$(echo "scale=0; $DL_BYTES / $ELAPSED / 1024" | bc)
        SPEED_STR="${SPEED_KB} KB/s"
      else
        SPEED_STR="..."
      fi
      printf "  [$arch] %s / %s MB (%s%%)  %s\n" "$DL_MB" "$ART_SIZE_MB" "$DL_PCT" "$SPEED_STR"
    fi
  done
  wait $CURL_PID
  CURL_EXIT=$?

  ELAPSED=$(($(date +%s) - START_TS))
  DL_BYTES=$(wc -c < "$OUTFILE" 2>/dev/null || echo 0)
  if [ "$ELAPSED" -gt 0 ] && [ "$DL_BYTES" -gt 0 ]; then
    AVG_SPEED=$(echo "scale=0; $DL_BYTES / $ELAPSED / 1024" | bc)
  else
    AVG_SPEED="??"
  fi
  printf "  [$arch] Done: %s bytes in %ss (%s KB/s avg)\n" "$DL_BYTES" "$ELAPSED" "$AVG_SPEED"

  if [ $CURL_EXIT -ne 0 ]; then
    echo "ERROR: curl failed with exit code $CURL_EXIT"
    return $CURL_EXIT
  fi

  echo "[$arch] Extracting..."
  unzip -o -q "$OUTFILE" -d "$IMAGEDIR"
  rm "$OUTFILE"
  echo "[$arch] Complete."
}

# Download both architectures in parallel
echo ""
download_artifact aarch64 &
PID_AARCH64=$!
download_artifact x86_64 &
PID_X86_64=$!

# Show overall progress while downloads run
REMAINING=$((2))
while [ $REMAINING -gt 0 ]; do
  sleep 5
  AARCH_DONE=0; X86_DONE=0
  kill -0 $PID_AARCH64 2>/dev/null || AARCH_DONE=1
  kill -0 $PID_X86_64 2>/dev/null || X86_DONE=1
  REMAINING=$((2 - AARCH_DONE - X86_DONE))
  if [ $REMAINING -gt 0 ]; then
    echo "  [$REMAINING/2 downloads remaining...]"
  fi
done

wait $PID_AARCH64 $PID_X86_64

# Rename to release naming convention
mv "$IMAGEDIR/nixos-libvirt-unstable-aarch64.qcow2" "$IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-aarch64.qcow2"
mv "$IMAGEDIR/nixos-libvirt-unstable-x86_64.qcow2" "$IMAGEDIR/nixos-libvirt-$NIXOS_LIBVIRT_TAG-x86_64.qcow2"

echo ""
echo "Done! Images in $IMAGEDIR/"
ls -lh "$IMAGEDIR/"*.qcow2
