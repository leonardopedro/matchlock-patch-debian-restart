#!/usr/bin/env bash
set -e

# This script applies the Matchlock Persistence & Debian Build Kit.
# It assumes the target matchlock repository is in a neighbor directory named 'matchlock'.

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(cd "$KIT_DIR/../matchlock" && pwd 2>/dev/null || echo "")"

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '../matchlock' not found."
    echo "This script must be run from within the patch kit folder,"
    echo "and the matchlock repository must be a neighbor folder."
    exit 1
fi

echo "Applying patch kit to $TARGET_DIR..."
echo "DEBUG: KIT_DIR=$KIT_DIR, TARGET_DIR=$TARGET_DIR"

# 1. Copy new files
echo "Copying new configuration and source files..."
cp -rv "$KIT_DIR/new-files/"* "$TARGET_DIR/"

# 2. Apply patch for modified files
echo "Applying changes to existing files..."
cd "$TARGET_DIR"

# Check if patch is already applied
if git apply --check --reverse "$KIT_DIR/changes.patch" > /dev/null 2>&1; then
    echo "Patch is already applied. Skipping."
elif git apply "$KIT_DIR/changes.patch"; then
    echo "Successfully applied using 'git apply'."
else
    echo "Standard 'git apply' failed, trying with 'patch --batch --fuzz=3'..."
    patch -p1 -N --batch --fuzz=3 < "$KIT_DIR/changes.patch"
    echo "Applied using 'patch' utility."
fi

echo ""
echo "=========================================================="
echo "Patch kit applied successfully to $TARGET_DIR!"
echo "=========================================================="
echo "You can now build the project using 'mise':"
echo "  cd $TARGET_DIR"
echo "  mise trust # For mise to trust the scripts"
echo "  mise run build:deb            # To build Matchlock .deb"
echo "  chmod a+x ./scripts/build-firecracker-deb.sh && mise run build:firecracker:deb # To build Firecracker.deb"
echo "=========================================================="


#rm -r ~/.matchlock/*
#leo@leoPC:/media/leo/e7ed9d6f-5f0a-4e19-a74e-83424bc154ba/matchlock-patch-debian-restart$ mkdir /home/leo/.matchlock/cache
#leo@leoPC:/media/leo/e7ed9d6f-5f0a-4e19-a74e-83424bc154ba/matchlock-patch-debian-restart$ ln -s /home/leo/.matchlock/cache ~/.cache/matchlock
#rm -r ~/.matchlock/* && mkdir ~/.matchlock/cache && sudo matchlock setup linux