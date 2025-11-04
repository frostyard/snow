# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/linuxsnow/debian-bootc-gnome:latest

COPY system_files /

ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build
    
# Finalize & Lint
RUN ln -s /var/usrlocal /usr/local && \
    bootc container lint
