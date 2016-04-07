#!/bin/sh

if ! [ -d "heka" ]; then
    git clone "git@github.com:mozilla-services/heka.git" || exit $?
fi

(cd heka; git checkout v0.10.0) || exit $?

mkdir -p heka/externals/heka-opsee || exit $?

cp -a nsq_input.go vendor heka/externals/heka-opsee || exit $?

cp heartbeat_filter.lua heka/sandbox/lua/filters/ || exit $?
cp librato_encoder.lua heka/sandbox/lua/encoders/ || exit $?

cp heka-config/plugin_loader.cmake heka/cmake/ || exit $?
cp heka-config/config.toml heka/examples/conf/hekad.toml || exit $?
cp heka-config/env.sh heka/ || exit $?
cp heka-config/dockerignore heka/.dockerignore || exit $?
cp heka-config/Dockerfile heka/ || exit $?
cp heka-config/Dockerfile.final heka/docker/ || exit $?

pushd heka/docker
./build_docker.sh
popd

st=$(docker ps -f "name=hek" --format="{{.Status}}")
if [ -z "$st" ]; then
    exit 1
fi
