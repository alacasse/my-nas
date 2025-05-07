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


# All of them:
docker compose --env-file  docker/.env.dev -f docker/vpn/docker-compose.yml up -d --build
