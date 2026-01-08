#!/bin/bash

# Script to generate tmpfiles.d configuration for ghostscript CMap symlinks
# This script lists all symlinks in /var/lib/ghostscript/CMap and creates
# a tmpfiles.d configuration file

set -euo pipefail

# Check if the source directory exists
CMAP_DIR="/var/lib/ghostscript/CMap"
OUTPUT_FILE="ghostscript.conf"

echo "# Generated ghostscript tmpfiles.d configuration"
echo "# This file creates symlinks for ghostscript CMap files"
echo "# Generated on: $(date)"
echo ""

if [[ ! -d "$CMAP_DIR" ]]; then
    echo "# Warning: $CMAP_DIR does not exist on this system" >&2
    echo "# This configuration is based on expected symlinks" >&2
    exit 1
fi

# Find all symlinks in the CMap directory and sort them
find "$CMAP_DIR" -maxdepth 1 -type l | sort | while read -r symlink; do
    # Get the basename of the symlink
    basename_link=$(basename "$symlink")
    
    # Get the target of the symlink (resolved)
    target=$(readlink "$symlink")
    
    # If target is relative, make it absolute
    if [[ ! "$target" =~ ^/ ]]; then
        target="$(dirname "$symlink")/$target"
        # Normalize the path
        target=$(realpath "$target" 2>/dev/null || echo "$target")
    fi
    
    # Output in tmpfiles.d format
    printf "L /var/lib/ghostscript/CMap/%s - - - - %s\n" "$basename_link" "$target"
done

echo ""
echo "# End of generated configuration"