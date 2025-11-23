# Project Context

## Environment
- **Host**: Windows (accessed via WSL/SSH).
- **VM**: Multipass VM named `nas-test` (Ubuntu 24.04).
- **Orchestration**: Docker Compose inside the VM.

## Execution
- **Do NOT** run scripts directly on the host.
- **ALWAYS** run scripts inside the VM using `multipass exec nas-test -- <command>`.
- The project directory is mounted/cloned into the VM at `/home/ubuntu/my-nas` (verify this path).

## Key Scripts
- `vpn-torrent-setup.sh`: Sets up the network and starts containers.
- `vpn-torrent-teardown.sh`: Stops containers and removes the network.
