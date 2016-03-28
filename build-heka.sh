#!/bin/sh

export GO15VENDOREXPERIMENT=1

if ! [ -d "heka" ]; then
    git clone "git@github.com:mozilla-services/heka.git" || exit $?
fi

(cd heka; git checkout v0.10.0) || exit $?

mkdir -p heka/externals/heka-opsee || exit $?

cp -a nsq_input.go vendor heka/externals/heka-opsee || exit $?

cp heartbeat_filter.lua heka/sandbox/lua/filters/ || exit $?

cp heka-config/plugin_loader.cmake heka/cmake/ || exit $?

pushd heka
source build.sh || exit $?
pushd docker
./build_docker.sh || exit $?
popd
popd


