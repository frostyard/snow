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
    lintian

RUN git clone https://github.com/frostyard/first-setup.git --depth 1 && \
    cd first-setup && \
    apt-get build-dep -y . && \
    dpkg-buildpackage

# Base Image
FROM ghcr.io/frostyard/debian-bootc-gnome:latest

COPY --from=builder /snow-first-setup_*.deb /tmp/
RUN apt-get install -y /tmp/snow-first-setup_*.deb

COPY system_files /

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_ID=${BUILD_ID}
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build && \
    /ctx/shared/build-initramfs && \
    /ctx/shared/finalize

# DEBUGGING
# RUN apt update -y && apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# Finalize & Lint
RUN bootc container lint
