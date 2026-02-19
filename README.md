# Matchlock & Firecracker: Build and Run Instructions

This guide provides the steps to apply the persistence patch, build the Debian packages with `mise`, and use the new CLI commands for VM restarts and allow-list updates.

## 0. Apply the Patch Kit

This kit contains both new files and a patch for existing files. It assumes your target `matchlock` repository is in a neighbor directory.

```bash
# From this directory (the patch kit)
./apply.sh

# Then move to the matchlock repository
cd ../matchlock
```

## 1. Create the Debian Packages

We use `mise` to automate the entire build and packaging process, including dependencies like Firecracker.

### Prerequisites

Ensure you have `mise` and the required tools installed:
- `golang` (>= 1.25)
- `cargo` (for building Firecracker)
- `dpkg-deb`

### Build Firecracker Debian Package
To download Firecracker source and build it as a Debian package:
```bash
mise run build:firecracker:deb
```
*Note: This will produce `firecracker_1.14.1_amd64.deb` in the root directory.*

### Build Matchlock Debian Package
To compile Matchlock and package it:
```bash
mise run build:deb
```
*Note: This will produce `matchlock_0.1.20_amd64.deb` in the root directory.*

## 2. Install the Packages

Install both packages using `dpkg`:
```bash
# Replace <arch> and versions as needed
sudo dpkg -i firecracker_1.14.1_amd64.deb
sudo dpkg -i matchlock_0.1.20_amd64.deb
```

## 3. Host System Setup (Required)

Matchlock requires a one-time setup on the host to enable IP forwarding and configure necessary permissions:

```bash
sudo matchlock setup linux
```

## 4. Using New Persistent Features

### Persistent Sandboxes
To create a persistent sandbox that keeps its filesystem changes, run with `--rm=false`:
```bash
matchlock run --image debian:trixie-slim --rm=false bash
```
*Take note of the VM ID.*

### Restart a Stopped VM
If a persistent sandbox stops, you can resume it using its ID:
```bash
matchlock start <vm-id>
```

### Update Allow-list at Runtime
You can add new hosts to the network allow-list while the VM is running (or stopped):
```bash
matchlock network allow <vm-id> "example.com" "api.openai.com"
```

## 5. Other CLI Commands

| Command | Description |
|---------|-------------|
| `matchlock list` | List all running and stopped sandboxes |
| `matchlock kill <id>` | Forcefully stop a running sandbox |
| `matchlock rm <id>` | Delete a persistent sandbox and its state |
| `matchlock inspect <id>` | View details (ID, Status, IP, Images) |

## 6. Example: Running an Agent with Persistence

1.  **Launch**: `matchlock run --image debian:trixie-slim --rm=false -it bash`
2.  **Install tools**: `apt update && apt install curl -y`
3.  **Exit & Stop**: `exit`
4.  **Restart & Verify**: `matchlock start <vm-id>` -> `curl --version` (still there!)
5.  **Expand network**: `matchlock network allow <vm-id> "github.com"`
