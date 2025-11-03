#!/bin/bash

set -ouex pipefail

# silence interactive prompts
export DEBIAN_FRONTEND=noninteractive
# Repository setup
sed -i 's/main/main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/*

# Initial update
apt-get update -y

# Add nonfree firmware
apt-get install -y \
	firmware-linux-nonfree

# Switch to IWD
apt-get install -y \
	iwd
apt-get remove -y \
	wpasupplicant

# Install gnome
apt-get install -y \
	task-gnome-desktop 
