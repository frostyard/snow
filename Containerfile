# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/frostyard/debian-bootc-gnome:latest AS builder

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install -y \
    git \
    devscripts \
    build-essential \
    fakeroot \
    dpkg-dev \
    lintian \
    python3-pytz

ARG DEBIAN_FRONTEND=noninteractive
RUN git clone https://github.com/frostyard/first-setup.git --depth 1 && \
    cd first-setup && \
    apt-get build-dep -y . && \
    dpkg-buildpackage && \
    mkdir -p /out && \
    mv /snow-first-setup_*.deb /out/


# Base Image
FROM ghcr.io/frostyard/debian-bootc-gnome:latest

COPY system_files /

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_ID=${BUILD_ID}
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=cache,dst=/var/lib/apt \
    --mount=type=cache,dst=/var/lib/dpkg/updates \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=builder,source=/out,target=/pkg \
    apt-get update && \
    apt-get install -y wget && \
    wget -O /tmp/chairlift.deb https://github.com/frostyard/chairlift/releases/download/continuous/chairlift.deb && \
    apt-get install -y /pkg/snow-first-setup_*.deb && \
    apt-get install -y /tmp/chairlift.deb && \
    /ctx/build && \
    /ctx/shared/build-initramfs && \
    /ctx/shared/finalize

# DEBUGGING
# RUN apt update -y && apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# Finalize & Lint
RUN bootc container lint
