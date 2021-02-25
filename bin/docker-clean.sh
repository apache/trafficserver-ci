#!/bin/sh

docker rm $(docker ps -q -f status=exited)
docker rmi $(docker images | awk '/<none>/ {print $3}')
