#!/usr/bin/env bash

version=${1:-5.1.4}
out=${2:-emqx-v${version}.deb}
os=ubuntu20.04
arch=amd64
wget -nc https://github.com/emqx/emqx/releases/download/v${version}/emqx-${version}-${os}-${arch}.deb -O ${out}
