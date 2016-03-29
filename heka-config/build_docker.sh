#!/bin/bash
# verbose/exit on error
set -xe
docker build -t mozilla/heka_base ..
docker build -t mozilla/heka_build .
docker run -v /var/run/docker.sock:/var/run/docker.sock -ti mozilla/heka_build
docker rmi mozilla/heka_build
