#!/bin/sh
# akebi96-tftp-aosp.sh: Install AOSP build on Akebi96
#
# Copyright (C) 2018,2019 Linaro Ltd.
# Masami Hiramatsu <masami.hiramatsu@linaro.org>
# This program is released under the MIT License, see LICENSE.

usage(){
  echo "Usage: $0 [CONFIG_FILE]"
  exit 0
}

SERVER_IP=192.168.11.1
BOARD_IP=192.168.11.10
GATEWAY_IP=192.168.11.1
NETMASK=255.255.255.0
LOGFILE=akebi96-install.log
MINICOM_OPT="" # you may need "-D devicefile"

if [ -f "$1" ]; then
  . $1
fi

export SERVER_IP
export BOARD_IP
export NETMASK
export GATEWAY_IP

DIR=`dirname $0`
exec minicom ${MINICOM_OPT} -S ${DIR}/akebi96-tftp-aosp.minicom -C $LOGFILE
