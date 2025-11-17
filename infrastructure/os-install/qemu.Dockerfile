FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    ovmf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]
