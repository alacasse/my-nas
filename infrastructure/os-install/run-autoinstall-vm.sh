#!/usr/bin/env bash
set -euo pipefail

MEMORY=4096
CPUS=2
DISK_SIZE=40G
USE_DOCKER=0
IMAGE_NAME=nas-qemu-autoinstall

print_usage() {
  cat <<USAGE
Usage: $0 [options] /path/to/autoinstall.iso
Options:
  -m <MB>       Memory size (default: 4096)
  -c <count>    vCPU count (default: 2)
  -d <size>     Disk size for test VM (default: 40G)
  --docker      Run QEMU inside a Docker container (builds image if needed)
  -h            Show this help
USAGE
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -m)
      MEMORY=$2; shift 2;;
    -c)
      CPUS=$2; shift 2;;
    -d)
      DISK_SIZE=$2; shift 2;;
    --docker)
      USE_DOCKER=1; shift;;
    -h|--help)
      print_usage; exit 0;;
    --)
      shift; break;;
    -*)
      echo "Unknown option: $1" >&2
      print_usage; exit 1;;
    *)
      ARGS+=("$1"); shift;;
  esac
done

if [[ ${#ARGS[@]} -ne 1 ]]; then
  echo "ISO path is required" >&2
  print_usage
  exit 1
fi

ISO_PATH=$(realpath "${ARGS[0]}")
if [[ ! -f "$ISO_PATH" ]]; then
  echo "ISO not found: $ISO_PATH" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ARTIFACT_DIR="$SCRIPT_DIR/artifacts"
mkdir -p "$ARTIFACT_DIR"
VM_DISK="$ARTIFACT_DIR/autoinstall-test.qcow2"
rm -f "$VM_DISK"

run_host_qemu() {
  if ! command -v qemu-system-x86_64 >/dev/null; then
    echo "qemu-system-x86_64 not found. Install QEMU or use --docker." >&2
    exit 3
  fi
  qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE" >/dev/null
  KVM_FLAG=""
  if [[ -e /dev/kvm ]]; then
    KVM_FLAG="-enable-kvm -cpu host"
  fi
  set -x
  qemu-system-x86_64 $KVM_FLAG -m "$MEMORY" -smp "$CPUS" \
    -drive file="$VM_DISK",if=virtio,format=qcow2 \
    -cdrom "$ISO_PATH" -boot d \
    -display none -serial mon:stdio
}

build_docker_image() {
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/qemu.Dockerfile" "$SCRIPT_DIR"
  fi
}

run_docker_qemu() {
  build_docker_image
  qemu_opts=(
    qemu-system-x86_64 -m "$MEMORY" -smp "$CPUS" -drive file=/workspace/disk.qcow2,if=virtio,format=qcow2 \
    -cdrom /workspace/installer.iso -boot d -display none -serial mon:stdio
  )
  qemu_extra=()
  if [[ -e /dev/kvm ]]; then
    qemu_extra+=("-enable-kvm" "-cpu" "host")
  fi
  qemu_img_cmd=(qemu-img create -f qcow2 /workspace/disk.qcow2 "$DISK_SIZE")
  docker run --rm -it \
    --privileged \
    ${DOCKER_KVM_DEVICE:-$( [[ -e /dev/kvm ]] && echo "--device /dev/kvm" )} \
    -v "$ARTIFACT_DIR":/workspace \
    -v "$ISO_PATH":/workspace/installer.iso:ro \
    "$IMAGE_NAME" /bin/bash -c "${qemu_img_cmd[*]} && ${qemu_opts[*]} ${qemu_extra[*]}"
}

if [[ $USE_DOCKER -eq 1 ]]; then
  run_docker_qemu
else
  run_host_qemu
fi
