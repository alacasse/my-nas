#!/bin/bash
set -e

# Configuration
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")
SOPS_CONFIG="${PROJECT_ROOT}/.sops.yaml"
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
VPN_CONFIG_DIR="${PROJECT_ROOT}/apps/qbittorrent/vpn-config"
TARGET_SECRET="${PROJECT_ROOT}/apps/qbittorrent/secret.yaml"
ENCRYPTED_SECRET="${PROJECT_ROOT}/apps/qbittorrent/secrets.enc.yaml"

# 1. Check Prerequisites
if ! command -v sops &> /dev/null; then
    echo "Error: sops is not installed."
    echo "Please install it first."
    exit 1
fi

if ! command -v age &> /dev/null; then
    echo "Error: age is not installed."
    echo "Please install it (e.g., 'sudo dnf install age')."
    exit 1
fi

# 2. Ensure Age Key Exists
if [ ! -f "$AGE_KEY_FILE" ]; then
    echo "Generating new Age key at $AGE_KEY_FILE..."
    mkdir -p "$(dirname "$AGE_KEY_FILE")"
    age-keygen -o "$AGE_KEY_FILE"
fi

PUBLIC_KEY=$(grep -oP "public key: \K.*" "$AGE_KEY_FILE")
echo "Using Age Public Key: $PUBLIC_KEY"

# 3. Ensure .sops.yaml Exists
if [ ! -f "$SOPS_CONFIG" ]; then
    echo "Creating .sops.yaml..."
    cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: .*/secrets.enc.yaml
    encrypted_regex: '^(data|stringData)$'
    age: '$PUBLIC_KEY'
EOF
fi

# 4. Read Credentials
echo "Reading credentials from $VPN_CONFIG_DIR..."
if [ ! -f "$VPN_CONFIG_DIR/credentials.conf" ]; then
    echo "Error: $VPN_CONFIG_DIR/credentials.conf not found."
    exit 1
fi

# Extract user/pass (assuming first line user, second line pass, or key=value)
# The user's format was not strictly key=value in previous turns, it was just lines in credentials.conf often.
# Let's inspect the file content format first?
# The user said: "Those files... are gitignored".
# I'll verify the format in a separate step or assume lines 1 and 2.
# Standard OpenVPN auth-user-pass file is:
# username
# password
VPN_USER=$(sed -n '1p' "$VPN_CONFIG_DIR/credentials.conf")
VPN_PASS=$(sed -n '2p' "$VPN_CONFIG_DIR/credentials.conf")

# Find the first .ovpn file
OVPN_FILE=$(find "$VPN_CONFIG_DIR" -name "*.ovpn" | head -n 1)
if [ -z "$OVPN_FILE" ]; then
    echo "Error: No .ovpn file found in $VPN_CONFIG_DIR."
    exit 1
fi
echo "Using OpenVPN config: $(basename "$OVPN_FILE")"

# 5. Generate Unencrypted Secret Manifest (Temporary)
echo "Generating secret manifest..."
# Combine everything into ONE secret to avoid SOPS multi-document issues
cat > "$TARGET_SECRET" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vpn-credentials
  namespace: torrents
type: Opaque
stringData:
  username: "$VPN_USER"
  password: "$VPN_PASS"
  credentials.conf: |
    $VPN_USER
    $VPN_PASS
  custom.ovpn: |
$(sed 's/^/    /' "$OVPN_FILE")
EOF

# 6. Encrypt
echo "Encrypting to $ENCRYPTED_SECRET..."
# Ignore .sops.yaml during creation with --config /dev/null
# Explicitly format as YAML to strip any ambiguity
cat "$TARGET_SECRET" | sops --encrypt --config /dev/null --age "$PUBLIC_KEY" --input-type yaml --output-type yaml --encrypted-regex '^(data|stringData)$' /dev/stdin > "$ENCRYPTED_SECRET"
rm "$TARGET_SECRET"

echo "Success! Encrypted secrets saved to $ENCRYPTED_SECRET"
echo "You can view them with: sops -d $ENCRYPTED_SECRET"
