---
description: Run the NAS setup script inside the Multipass VM
---

To run the setup script, we must execute it inside the `nas-test` VM using `multipass`.

1. Run the setup script:
   ```bash
   multipass exec nas-test -- /home/ubuntu/my-nas/vpn-torrent-setup.sh
   ```
   *(Note: Adjust the path inside the VM if it differs from `/home/ubuntu/my-nas`)*
