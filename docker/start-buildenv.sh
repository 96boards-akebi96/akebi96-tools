#!/bin/sh
# run.sh: Run a build environment container
#
# Copyright (C) 2017 Linaro Ltd.
# Masami Hiramatsu <masami.hiramatsu@linaro.org>
# This program is released under the MIT License, see LICENSE.

# Virtual home directory for this container
HOMEDIR=${HOME}/linaro
ENVOPT=
SETUP=1
CMD=
_UID=`id -u`

set -e

usage(){
  echo "Usage: $0 [-h HOME] [-u UID] [CMD]"
  exit 0
}

TAG=akebi96-dev
NAME=akebi96-dev

# use run.config for configuration
[ -f ./run.config ] && . ./run.config

# setup Proxy env
if [ "${http_proxy}" ]; then
  OPT="${OPT} -e http_proxy=${http_proxy}"
fi
if [ "${https_proxy}" ]; then
  OPT="${OPT} -e https_proxy=${https_proxy}"
fi

OPT="$OPT --name=$NAME --hostname=$NAME"
if docker ps -a --format="{{.Status}}" --filter=name=$NAME | grep Up ; then
  echo "$NAME is already running. Please find it."
  exit 0
fi
RERUN=`docker ps -a --format="{{.ID}}" --filter=name=$NAME`

while [ $# -ne 0 ] ; do
  case $1 in
    -h) HOMEDIR=$2; shift 2;;
    -u) _UID=$2: shift 2;;
    -*) usage;;
    *) CMD="$@"; shift $#;;
  esac
done

# Setup git user information by copying current one
mkdir -p ${HOMEDIR}
if [ $SETUP -ne 0 -a ! -e ${HOMEDIR}/.gitconfig ]; then
  email=`git config --global --get user.email`
  uname=`git config --global --get user.name`
  if [ x"$email" != x ]; then
    git config --file ${HOMEDIR}/.gitconfig --add user.email "$email"
  fi
  if [ x"$uname" != x ]; then
    git config --file ${HOMEDIR}/.gitconfig --add user.name "$uname"
  fi
fi

# Start container with new home and ssh keys
if [ -n "$RERUN" ]; then
  exec docker start -ai $RERUN
else
  exec docker run --rm -ti \
	-v ${HOMEDIR}:/home/linaro \
	-v ${HOME}/.ssh:/home/linaro/.ssh \
	-u ${_UID} ${ENVOPT} ${OPT} ${TAG} ${CMD}
fi
