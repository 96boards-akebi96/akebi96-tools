#!/bin/sh
# build-docker.sh: Build docker containers for LD20
#
# Copyright (C) 2017,2019 Linaro Ltd.
# Masami Hiramatsu <masami.hiramatsu@linaro.org>
# This program is released under the MIT License, see LICENSE.

set -e
if [ "$DEBUG" ]; then
  set -x
fi

# Default configurations (overwritten by build.config)
RELEASE="8.2-2019.01"

[ -f build.config ] && . ./build.config

# setup Proxy env
BUILD_OPT=
if [ "${http_proxy}" ]; then
  BUILD_OPT="--build-arg http_proxy=${http_proxy}"
fi
if [ "${https_proxy}" ]; then
  BUILD_OPT="${BUILD_OPT} --build-arg https_proxy=${https_proxy}"
fi

DOCKER=`which docker` || :
if [ -z "$DOCKER" ]; then
  echo "Please install docker"
  echo "e.g. apt install docker"
  exit 1
fi

image_exist(){ # tag
  docker inspect "$1" > /dev/null 2>&1
  return $?
}

get_hash() { #file
  if git log -n 1 $1 > /dev/null 2>&1 ;then
    git log -n 1 --oneline $1 | cut -f1 -d " "
  else
    md5sum $1 | cut -f1 -d " "
  fi
}

build_image() { #dir rev [build-args]
  TAG=$1:$2
  HTAG=$1:`get_hash $1/dockerfile`
  DIR=$1
  shift 2
  if ! image_exist $HTAG ; then
    echo "Building $TAG ..."
    docker build $BUILD_OPT -t $HTAG $DIR $*
    docker tag $HTAG $TAG
  else
    echo "$TAG is the latest version."
  fi
}

echo "Update Akebi96 build environment"
_UID=`id -u`
build_image akebi96-dev ${_UID}-${RELEASE} \
         --build-arg=RELEASE=$RELEASE \
	 --build-arg=UID=${_UID}

# Set the default latest image
docker tag akebi96-dev:${_UID}-${RELEASE} akebi96-dev/${_UID}:latest

# Build tftp server
echo "Update tftp server image"
build_image tftp latest

echo "Finished"
