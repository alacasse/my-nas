# Testing Install (Multipass on Fedora)

Use Multipass and a disposable Ubuntu VM to rehearse the NAS setup. This includes firewalld tweaks from `multipass-firewalld-fix.md`, pulling this repo into the VM, and installing Docker plus the current compose stacks.

## 1) Prereqs on Fedora
- KVM OK: `sudo virt-host-validate` should mostly PASS.
- Firewalld running (default).
- Snapd installed: `sudo dnf install -y snapd && sudo ln -s /var/lib/snapd/snap /snap`
- (Already applied) see `multipass-firewalld-fix.md` for background.

## 2) Install Multipass
```bash
sudo snap install multipass
sudo systemctl enable --now snap.multipass.multipassd.service
```
Ensure driver is qemu: `multipass get local.driver` (set with `sudo multipass set local.driver=qemu` if needed).

## 3) Firewalld allowances (persistent)
```bash
sudo firewall-cmd --permanent --zone=trusted --add-interface=mpqemubr0
sudo firewall-cmd --permanent --zone=trusted --add-masquerade
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i mpqemubr0 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -o mpqemubr0 -j ACCEPT
sudo firewall-cmd --reload
```
Verify: `sudo firewall-cmd --get-active-zones` and `sudo firewall-cmd --permanent --direct --get-all-rules`.

## 4) Launch the Ubuntu VM
```bash
multipass launch 24.04 --name nas-test --memory 4G --disk 20G
multipass list
multipass info nas-test
```

## 5) Put this repo in the VM
```bash
multipass shell nas-test
sudo apt update && sudo apt install -y git
git clone git@github.com:alacasse/my-nas.git ~/my-nas   # or multipass transfer from host
or
multipass transfer --recursive --parents ./ nas-test:/home/ubuntu/my-nas
or
multipass mount ./ nas-test:/home/ubuntu/my-nas # works well for iterating on dev
cd ~/my-nas
```

## 6) Install Docker (NAS bootstrap dry-run)
```bash
sudo TARGET_USER=ubuntu ./infrastructure/install-docker.sh
newgrp docker   # or re-login to pick up docker group
docker ps       # should work without sudo
```

## 7) Exercise current stacks (compose)
```bash
./vpn-torrent-setup.sh          # vpn + torrent
./nginx-setup.sh                # or ./start.sh to run both stacks
docker compose --env-file docker/.env.dev -f docker/vpn/docker-compose.yml ps
docker compose --env-file docker/.env.dev -f docker/torrent/docker-compose.yml ps
docker compose -f docker/nginx/docker-compose.yml ps
./scripts/check-vpn-torrent.sh  # basic network/container/health checks
```
Storage defaults to `/home/ubuntu/nas-volumes` (see `docker/.env.dev`); mounts are auto-created by the setup script. Hit the exposed ports/hosts from inside the VM (check compose files for port mappings). The check script also tries to reach the torrent UI from the VPN container and fetch an external IP via the VPN; warnings may appear if outbound network is blocked or curl/wget is absent—rebuild the VPN image to add tools (Dockerfile already has curl).
Setup in /etc/hosts: 10.120.238.107 logs.nas.test torrent.nas.test portainer.nas.test filebrowser.nas.test

## 8) Observability stack (logs + metrics)
```bash
docker compose -f docker/observability/docker-compose.yml up -d
docker compose -f docker/observability/docker-compose.yml ps
```
- Loki for logs, Promtail scraping Docker/system logs, Prometheus scraping node-exporter + smartctl-exporter, Grafana on :3000 (admin/admin by default).
- Add `/etc/hosts` entry for Grafana via nginx: `logs.nas.test <VM_IP>` then visit http://logs.nas.test (nginx proxies to Grafana). You can also hit http://<VM_IP>:3000 directly.

10.120.238.107 logs.nas.test torrent.nas.test portainer.nas.test filebrowser.nas.test
Then hit http://logs.nas.test (Grafana via nginx), http://torrent.nas.test (qbittorrent UI), etc. If you expose services directly (e.g., Grafana on 3000), you can also browse to http://10.120.238.107:3000. The 172.x/10.x you see inside Docker are internal; keep using the Multipass IP for host→VM access.

## 9) (Optional) Kubernetes rehearsal inside VM
- Install k3d: `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash`
- Create cluster: `k3d cluster create nas-sim -p "80:80@loadbalancer" -p "443:443@loadbalancer"`
- Context: `kubectl config use-context k3d-nas-sim`
- Note: `clusters/dev` currently has no K8s manifests; add them before applying.

## 10) Teardown when done
```bash
exit   # leave VM shell
multipass delete nas-test
multipass purge
```

Notes:
- If launch times out, confirm firewalld rules and daemon: `sudo systemctl status snap.multipass.multipassd.service`.
- Firewalld changes above are permanent across reboots.***
