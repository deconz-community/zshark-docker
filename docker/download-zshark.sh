#!/bin/bash

set -ex

ZSHARK_VERSION=$1
PLATFORM=$2

if echo "${PLATFORM}" | grep -qE "amd64";
then
  URL="http://phoscon.de/downloads/zshark/ubuntu/zshark-${ZSHARK_VERSION}-amd64.bionic.deb"
fi
if echo "${PLATFORM}" | grep -qE "v7";
then
  URL="http://phoscon.de/downloads/zshark/raspbian/zshark-${ZSHARK_VERSION}.deb"
fi

curl -vv "${URL}" -o /zshark${DEV}.deb

