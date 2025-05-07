# Use the official Gluetun image as base
FROM qmcgaw/gluetun

# Install debugging tools
RUN apk update && apk add --no-cache \
    bash \
    curl \
    iproute2 \
    iputils \
    bind-tools \
    net-tools \
    busybox-extras \
    nano \
    htop
