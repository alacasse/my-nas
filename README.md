# my-nas

# To inspect a running docker container
docker inspect filebrowser

# To start nas
docker compose --env-file  docker/.env.dev -f docker/nas/docker-compose.yml up -d --build

# To stop nas
docker compose -f docker/nas/docker-compose.yml down

# To start vpn
docker compose -f docker/vpn/docker-compose.yml up -d --build

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
portainer.localhost

# Access portainer:
torrent.localhost

# If portainer cannot find its volumes while starting
docker rm portainer
docker volume rm portainer_portainer_data