#!/bin/bash
set -e

# 1. Configuration
PACKAGE_NAME="firecracker"
MAINTAINER="Local Package Builder <builder@example.com>"
DESCRIPTION="Secure and fast microVMs for serverless computing."

# 2. Determine Architecture
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64)  DEB_ARCH="amd64"; FIRE_ARCH="x86_64" ;;
    aarch64) DEB_ARCH="arm64"; FIRE_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH_RAW"; exit 1 ;;
esac

# 3. Get Latest Version from GitHub
echo "Fetching latest Firecracker version..."
RELEASE_URL="https://github.com/firecracker-microvm/firecracker/releases"
LATEST_TAG=$(basename $(curl -fsSLI -o /dev/null -w %{url_effective} ${RELEASE_URL}/latest))
VERSION=${LATEST_TAG#v} # Remove the 'v' prefix for Debian versioning

echo "Targeting version: $LATEST_TAG ($DEB_ARCH)"

# 4. Download and Extract Binaries
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

TARBALL="firecracker-${LATEST_TAG}-${FIRE_ARCH}.tgz"
DOWNLOAD_URL="${RELEASE_URL}/download/${LATEST_TAG}/${TARBALL}"

echo "Downloading $TARBALL from $DOWNLOAD_URL..."
curl -LOf "$DOWNLOAD_URL"
tar -xzf "$TARBALL"

# Files are extracted into a directory named release-vX.X.X-ARCH/
EXTRACTED_DIR="release-${LATEST_TAG}-${FIRE_ARCH}"

# 5. Create Debian Package Structure
PKG_DIR="${PACKAGE_NAME}_${VERSION}_${DEB_ARCH}"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/DEBIAN"

cp "$EXTRACTED_DIR/firecracker-${LATEST_TAG}-${FIRE_ARCH}" "$PKG_DIR/usr/bin/firecracker"
cp "$EXTRACTED_DIR/jailer-${LATEST_TAG}-${FIRE_ARCH}" "$PKG_DIR/usr/bin/jailer"
chmod +x "$PKG_DIR/usr/bin/firecracker" "$PKG_DIR/usr/bin/jailer"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 Firecracker is an open-source virtualization technology that is 
 purpose-built for creating and managing secure, multi-tenant 
 containers and serverless functions based on microVMs.
EOF

# 6. Build the package
dpkg-deb --build "$PKG_DIR"

# 7. Move output to script's original location
mv "${PKG_DIR}.deb" "$OLDPWD/"
cd "$OLDPWD"

echo ""
echo "============================================"
echo "Firecracker Debian package built successfully!"
echo "============================================"
echo "Package file: ${PKG_DIR}.deb"
