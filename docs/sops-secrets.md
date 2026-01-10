# SOPS Secret Management

## Overview

This project uses [SOPS](https://github.com/mozilla/sops) with AGE encryption for Kubernetes secrets. Secrets are encrypted at rest in version control and decrypted at deployment time.

## Installation

### Option 1: Bundled Binary (Linux AMD64)

This project includes a pre-built SOPS binary for convenience:

```bash
# Make executable
chmod +x sops-v3.8.1.linux.amd64

# Verify version
./sops-v3.8.1.linux.amd64 --version
# sops 3.8.1
```

**Location:** `sops-v3.8.1.linux.amd64` (project root)

### Option 2: Package Manager (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install sops
sops --version
```

### Option 3: Homebrew (macOS)

```bash
brew install sops
sops --version
```

### Option 4: Go Install

```bash
go install github.com/mozilla/sops/v3/cmd/sops@latest
sops --version
```

### Option 5: Download Binary

```bash
# Download from GitHub releases
curl -LO https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
```

## AGE Key Setup

For local development, you'll need to generate or import an AGE key pair:

```bash
# Generate a new key pair (outputs to age.txt)
age-keygen -o age.txt

# Export for SOPS usage
export SOPS_AGE_KEY_FILE=age.txt

# The public key must be added to .sops.yaml for encryption to work
```

**Security Note:** Store the private key (age.txt) securely. Never commit it to version control. Consider using 1Password, HashiCorp Vault, or a similar secrets manager.

## File Naming Convention

Encrypted secret files must be named `secrets.enc.yaml` to match the pattern in `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: .*/secrets.enc.yaml
    encrypted_regex: '^(data|stringData)$'
    age: 'age19m70lg0tsj5lrx55f8cr36re9kzh5gp8z3525flcpkm4d7zjf3gs8ggc5u'
```

## Adding a New Secret

### Step 1: Create the unencrypted template

Create a standard Kubernetes Secret manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: nas
type: Opaque
stringData:
  username: admin
  password: ChangeMe12345!
```

### Step 2: Rename to encrypted file

```bash
mv apps/appname/secret.yaml apps/appname/secrets.enc.yaml
```

### Step 3: Encrypt with SOPS

```bash
# Using the bundled SOPS binary
chmod +x sops-v3.8.1.linux.amd64
./sops-v3.8.1.linux.amd64 --encrypt \
  --age "age19m70lg0tsj5lrx55f8cr36re9kzh5gp8z3525flcpkm4d7zjf3gs8ggc5u" \
  apps/appname/secrets.enc.yaml > apps/appname/secrets.enc.yaml.tmp && \
mv apps/appname/secrets.enc.yaml.tmp apps/appname/secrets.enc.yaml
```

### Step 4: Update kustomization.yaml

In the app's `kustomization.yaml`, reference the encrypted file:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - secrets.enc.yaml  # Not secret.yaml
```

### Step 5: Remove unencrypted file

```bash
rm apps/appname/secret.yaml
```

## Editing Existing Secrets

### Decrypt for editing

```bash
sops --decrypt apps/appname/secrets.enc.yaml
```

Edit the decrypted output, then re-encrypt:

```bash
sops --encrypt --age "age19m70lg0tsj5lrx55f8cr36re9kzh5gp8z3525flcpkm4d7zjf3gs8ggc5u" \
  apps/appname/secrets.enc.yaml > apps/appname/secrets.enc.yaml.tmp && \
mv apps/appname/secrets.enc.yaml.tmp apps/appname/secrets.enc.yaml
```

### Using sops interactive edit

```bash
sops apps/appname/secrets.enc.yaml
```

This opens the default editor with the file decrypted. Saving and exiting automatically re-encrypts.

## AGE Key Management

The AGE public key is defined in `.sops.yaml`:

```
age19m70lg0tsj5lrx55f8cr36re9kzh5gp8z3525flcpkm4d7zjf3gs8ggc5u
```

**Important:**
- The private key must be stored securely (1Password, HashiCorp Vault, etc.)
- Never commit the private key to version control
- The private key must be available in CI/CD for deployment decryption
- For local development, export `SOPS_AGE_KEY_FILE` pointing to the key

## CI/CD Decryption

In your CI/CD pipeline, provide the AGE private key via environment variable:

```yaml
# GitHub Actions example
- name: Decrypt secrets
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    echo "$SOPS_AGE_KEY" > age.key
    export SOPS_AGE_KEY_FILE=age.key
    kubectl apply -k apps/nas/filebrowser/
```

## Troubleshooting

### "Error loading SOPS age key"

Ensure the AGE key is valid and accessible:

```bash
# Check key file exists
cat $SOPS_AGE_KEY_FILE

# Or use inline key
export SOPS_AGE_KEY="<private-key-content>"
```

### "Key not found for recipient"

The AGE public key in `.sops.yaml` must match the private key used for decryption.

### Decryption succeeds but values are empty

Check that `encrypted_regex` matches your secret structure. This project uses `^(data|stringData)$` for Kubernetes Secrets.

## Security Best Practices

1. **Never commit plain-text secrets** - Always use `secrets.enc.yaml`
2. **Use unique keys per environment** - Consider separate AGE keys for dev/prod
3. **Rotate keys periodically** - Generate new AGE key pairs and re-encrypt
4. **Audit secret access** - Log who accesses secrets in production
5. **Use short-lived credentials** - Rotate application credentials regularly

## Reference Files

- [`.sops.yaml`](../.sops.yaml) - SOPS configuration
- [`apps/nas/filebrowser/secrets.enc.yaml`](../apps/nas/filebrowser/secrets.enc.yaml) - Example encrypted secret
- [`apps/networking/qbittorrent/secrets.enc.yaml`](../apps/networking/qbittorrent/secrets.enc.yaml) - Another example
