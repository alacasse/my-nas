#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/ubuntu-24.04.3-live-server-amd64.iso" >&2
  exit 1
fi

BASE_ISO=$1
if [[ ! -f "$BASE_ISO" ]]; then
  echo "Base ISO not found: $BASE_ISO" >&2
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUTPUT_DIR="$SCRIPT_DIR/artifacts"
mkdir -p "$OUTPUT_DIR"

WORK_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

ISO_ROOT="$WORK_DIR/iso"
mkdir -p "$ISO_ROOT"

# Extract ISO contents
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$ISO_ROOT" >/dev/null

# Inject autoinstall files
mkdir -p "$ISO_ROOT/nocloud"
cp "$SCRIPT_DIR/autoinstall.yaml" "$ISO_ROOT/nocloud/user-data"
cat <<'METADATA' > "$ISO_ROOT/nocloud/meta-data"
instance-id: ubuntu-autoinstall
local-hostname: nas
METADATA

# Ensure boot configs automatically pass autoinstall parameters
for cfg in "$ISO_ROOT/boot/grub/grub.cfg" "$ISO_ROOT/isolinux/txt.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/---$/autoinstall ds=nocloud;s=\/cdrom\/nocloud\/ ---/' "$cfg"
  fi
done

# Build new ISO
OUTPUT_ISO="$OUTPUT_DIR/ubuntu-24.04.3-autoinstall.iso"
xorriso -as mkisofs \
  -r -V "ubuntu-autoinstall" \
  -o "$OUTPUT_ISO" \
  -J -l -cache-inodes \
  -isohybrid-mbr "$ISO_ROOT/isolinux/isohdpfx.bin" \
  -b isolinux/isolinux.bin \
     -c isolinux/boot.cat \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
     -no-emul-boot \
  "$ISO_ROOT" >/dev/null

echo "Created $OUTPUT_ISO"
