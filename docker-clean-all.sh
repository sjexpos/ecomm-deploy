#!/bin/bash

docker container prune --force
docker image prune --force
docker network prune --force
docker volume prune --force

