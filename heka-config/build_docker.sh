#!/bin/bash
# verbose/exit on error
set -xe
docker build -t mozilla/heka_base ..
docker build -t mozilla/heka_build .
docker rm -f mozilla/heka_build || true
docker run -v /var/run/docker.sock:/var/run/docker.sock -ti mozilla/heka_build
docker rm -f mozilla/heka_build || true
docker rmi mozilla/heka_build || true
