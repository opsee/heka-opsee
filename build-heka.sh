#!/bin/sh

export GO15VENDOREXPERIMENT=1

git submodule init && git submodule update || exit 1

mkdir -p heka/externals/heka-opsee || exit 1

cp -a nsq_input.go vendor heka/externals/heka-opsee || exit 1

cp heartbeat_filter.lua heka/sandbox/lua/filters/ || exit 1

cp heka-config/plugin_loader.cmake heka/cmake/ || exit 1

cd heka; . ./build.sh
