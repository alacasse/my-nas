# Ubuntu Autoinstall Bootstrap

This directory contains the files needed to produce a reproducible Ubuntu Server 24.04.3 LTS installer for the NAS SSD and to test it locally before touching hardware.

## Files

- `autoinstall.yaml` – cloud-init/autoinstall definition (disk layout, user, packages). Replace the placeholder password hash before real use.
- `build-autoinstall-iso.sh` – helper script that injects the autoinstall files into an official Ubuntu ISO and emits a new ISO under `artifacts/`.
- `run-autoinstall-vm.sh` – spins up a disposable QEMU/KVM VM (or QEMU-in-Docker when KVM is unavailable) using the generated ISO so you can validate the installer end-to-end.

## Workflow

1. Download the official Ubuntu Server 24.04.3 LTS ISO (`ubuntu-24.04.3-live-server-amd64.iso`) and place it beside this README.
2. Customize `autoinstall.yaml`:
   - Update hostname, username, SSH authorized keys, and password hash (`mkpasswd --method=SHA-512`).
   - Adjust the target disk ID if your SSD shows up under a different `/dev/disk/by-id/` name.
3. Run `./build-autoinstall-iso.sh ubuntu-24.04.3-live-server-amd64.iso` – outputs `artifacts/ubuntu-24.04.3-autoinstall.iso`.
4. Test locally with `./run-autoinstall-vm.sh artifacts/ubuntu-24.04.3-autoinstall.iso`.
   - By default the script uses host `qemu-system-x86_64` with KVM acceleration when available.
   - Pass `--docker` to run QEMU inside a Docker container if you cannot install QEMU on the host; Docker must run in privileged mode (the script handles the flag).
5. Once validated, mount the ISO via Supermicro IPMI virtual media and boot the NAS to perform the real install. No manual input should be required beyond confirming boot order.

## Why Autoinstall + Ansible?

- **Autoinstall** covers the “day 0” provisioning: partition SSD, configure locales, create initial admin user, preinstall packages like `zfsutils-linux`, etc. It guarantees every reinstall is identical.
- **Ansible** (planned next) handles “day 1+” configuration: additional packages, hardening, k3s prerequisites, Flux bootstrap, etc. It is idempotent and rerunnable, and it is easy to test inside VMs spun up by `run-autoinstall-vm.sh`.

By storing both layers here, you can iterate locally, commit to Git, and only then apply the exact same artifacts to the NAS hardware.
