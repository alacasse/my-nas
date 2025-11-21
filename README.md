
# To start torrent
docker compose -f docker/torrent/docker-compose.yml up -d --build

# Start portainer
docker compose --env-file ./docker/.env.dev -f ./docker/portainer/docker-compose
.yml up -d --build

# Start/stop Nginx
./nginx-setup.sh
./nginx-teardown.sh

# All of them:
docker compose --env-file  docker/.env.dev -f docker/vpn/docker-compose.yml up -d --build

# Access portainer:
portainer.nas.test

# Access portainer:
torrent.nas.test

# If portainer cannot find its volumes while starting
docker rm portainer
docker volume rm portainer_portainer_data