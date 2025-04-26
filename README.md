# my-nas

# To inspect a runnign docker container
docker inspect filebrowser

# To start nas
docker compose --env-file  docker/nas/.env.dev -f docker/nas/docker-compose.yml up -d --build

# To stop nas
docker compose -f docker/nas/docker-compose.yml down

