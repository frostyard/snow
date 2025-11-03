#!/bin/bash

set -ouex pipefail

# Initial update
apt-get update -y

# Switch to IWD
apt-get install -y \
	iwd
apt-get remove -y \
	wpasupplicant
