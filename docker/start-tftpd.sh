#!/bin/sh
# start-tftp.sh: Run tftp server container for tftp boot
#
# Copyright (C) 2017 Linaro Ltd.
# Masami Hiramatsu <masami.hiramatsu@linaro.org>
# This program is released under the MIT License, see LICENSE.

if [ -z "$1" -o ! -d "$1" ]; then
  echo "$1 is not a directory."
  echo "Usage: $0 <tftpboot directory>"
  exit 0
fi
DIR=$(cd $1; pwd)

if docker ps -a --format="{{.Status}}" --filter=name=tftpd | grep Up ; then
  echo "tftpd is already running. Please kill it first."
  exit 0
fi
RERUN=`docker ps -a --format="{{.ID}}" --filter=name=tftpd`
if [ "$RERUN" ]; then
  docker start tftpd
else
  docker run -d -p 69:69 -p 69:69/udp -v $DIR:/var/lib/tftpboot --name tftpd tftp:latest
fi
