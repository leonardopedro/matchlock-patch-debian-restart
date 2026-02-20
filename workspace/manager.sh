#!/bin/bash
# manager.sh

# 1. GUEST OPTIMIZATION: Remount Rootfs
# noatime: Stops disk writes on every file read.
# commit=60: Tells Ext4 to only sync metadata every 60 seconds (instead of 5).
# This allows Btrfs on the host to write data in large, efficient chunks.
mount -o remount,noatime,commit=60 / 2>/dev/null || true

# 2. GUEST OPTIMIZATION: Reclaim Space (TRIM)
# This tells the Host Btrfs which blocks are actually empty.
# Matchlock supports this via virtio-blk discard.
fstrim -v /

# 3. Standard Setup
. /nix/etc/profile.d/nix.sh

# Link shared data
mkdir -p /workspace/openclaw_data
ln -sfn /workspace/openclaw_data "$HOME/.openclaw"

# 4. Run OpenClaw
if ! command -v openclaw >/dev/null; then
    echo ">>> First run: Installing OpenClaw..."
    nix-env -iA nixpkgs.nodejs_24
    npm install -g openclaw@latest
fi

echo ">>> Launching OpenClaw..."
exec openclaw gateway --force