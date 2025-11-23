---
description: Run the NAS teardown script inside the Multipass VM
---

To run the teardown script, we must execute it inside the `nas-test` VM using `multipass`.

1. Run the teardown script:
   ```bash
   multipass exec nas-test -- /home/ubuntu/my-nas/vpn-torrent-teardown.sh
   ```
