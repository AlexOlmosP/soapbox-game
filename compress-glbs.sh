#!/bin/bash
# Compress all GLB files in the project root using gltf-transform.
# - Backs up originals to glb-originals/ (gitignored)
# - Resizes textures to 512x512 max
# - Applies Draco geometry compression
# Run from project root: ./compress-glbs.sh

set -e

mkdir -p glb-originals

# Find all GLBs in the root (not in subdirectories)
TOTAL_BEFORE=0
TOTAL_AFTER=0
COUNT=0

for glb in *.glb; do
  [ -f "$glb" ] || continue

  # Skip if already in originals (means we're re-running on a clean state)
  if [ -f "glb-originals/$glb" ] && [ ! -L "$glb" ]; then
    SIZE_BEFORE=$(stat -c%s "$glb" 2>/dev/null || stat -f%z "$glb")
  else
    cp "$glb" "glb-originals/$glb"
    SIZE_BEFORE=$(stat -c%s "$glb" 2>/dev/null || stat -f%z "$glb")
  fi

  echo "[$((COUNT+1))] Compressing $glb..."

  # Step 1: resize textures to 512 max
  npx --yes @gltf-transform/cli@4 resize --width 512 --height 512 "$glb" "_tmp_$glb" 2>&1 | tail -1

  # Step 2: apply Draco compression
  npx --yes @gltf-transform/cli@4 draco "_tmp_$glb" "$glb" 2>&1 | tail -1

  rm -f "_tmp_$glb"

  SIZE_AFTER=$(stat -c%s "$glb" 2>/dev/null || stat -f%z "$glb")
  TOTAL_BEFORE=$((TOTAL_BEFORE + SIZE_BEFORE))
  TOTAL_AFTER=$((TOTAL_AFTER + SIZE_AFTER))
  COUNT=$((COUNT + 1))

  printf "    %s -> %s\n" \
    "$(numfmt --to=iec $SIZE_BEFORE 2>/dev/null || echo "${SIZE_BEFORE}B")" \
    "$(numfmt --to=iec $SIZE_AFTER 2>/dev/null || echo "${SIZE_AFTER}B")"
done

echo ""
echo "Compressed $COUNT files"
echo "Total: $(numfmt --to=iec $TOTAL_BEFORE 2>/dev/null || echo "${TOTAL_BEFORE}B") -> $(numfmt --to=iec $TOTAL_AFTER 2>/dev/null || echo "${TOTAL_AFTER}B")"
