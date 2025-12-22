# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/frostyard/debian-bootc-gnome:latest

COPY system_files /

# Copy Homebrew files from the brew image
COPY --from=ghcr.io/frostyard/brew:latest /system_files /

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_ID=${BUILD_ID}
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    apt-get update && \
    apt-get install -y wget && \
    wget -O /tmp/nbc.deb https://github.com/frostyard/nbc/releases/download/v0.7.12/nbc_0.7.12_amd64.deb && \
    wget -O /tmp/snow-first-setup.deb https://github.com/frostyard/first-setup/releases/download/continuous/snow-first-setup.deb && \
    wget -O /tmp/chairlift.deb https://github.com/frostyard/chairlift/releases/download/continuous/chairlift.deb && \
    apt-get install -y /tmp/snow-first-setup.deb && \
    apt-get install -y /tmp/chairlift.deb && \
    apt-get install -y /tmp/nbc.deb && \
    /ctx/build && \
    /ctx/shared/build-initramfs && \
    /ctx/shared/finalize

# DEBUGGING
# RUN apt update -y && apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# Finalize & Lint
RUN bootc container lint
