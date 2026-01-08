#!/bin/bash

# Update ghostscript.conf with current symlinks
# This script regenerates the tmpfiles.d configuration file
# It is expected to be run on a host system with ghostscript installed, and therefore
# not inside a container or build process.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_FILE="$SCRIPT_DIR/system_files/usr/lib/tmpfiles.d/ghostscript.conf"

echo "Updating ghostscript.conf..."

# Use the basic script to generate new content
if "$SCRIPT_DIR/generate_ghostscript_tmpfiles.sh" > "$TARGET_FILE"; then
    echo "Successfully updated $TARGET_FILE"
    echo "Found $(grep -c '^L ' "$TARGET_FILE") symlink entries"
else
    echo "Error: Failed to update $TARGET_FILE" >&2
    exit 1
fi