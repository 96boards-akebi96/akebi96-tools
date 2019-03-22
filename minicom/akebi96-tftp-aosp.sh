#!/bin/sh
# akebi96-tftp-aosp.sh: Install AOSP build on Akebi96
#
# Copyright (C) 2018,2019 Linaro Ltd.
# Masami Hiramatsu <masami.hiramatsu@linaro.org>
# This program is released under the MIT License, see LICENSE.

usage(){
  echo "Usage: $0 [-c CONFIG_FILE] [firmware]"
  exit 0
}

FWINST=0
SERVER_IP=192.168.11.1
BOARD_IP=192.168.11.10
GATEWAY_IP=192.168.11.1
NETMASK=255.255.255.0
LOGFILE=akebi96-install.log
MINICOM_OPT="" # you may need "-D devicefile"

CONFIG=

while [ $# -ne 0 ]; do
  case $1 in
  -c) CONFIG=$2 ; shift 2;;
  firmware) FWINST=1; shift 1;;
  *) usage ;;
  esac
done

if [ -n "$CONFIG" -a -f "$CONFIG" ]; then
  . $CONFIG
fi

if [ $FWINST -ne 0 ]; then
  INITCNT=0	# Install AOSP and firmware
else
  INITCNT=1	# Install AOSP only
fi

export INITCNT
export SERVER_IP
export BOARD_IP
export NETMASK
export GATEWAY_IP

DIR=`dirname $0`
exec minicom ${MINICOM_OPT} -S ${DIR}/akebi96-tftp-aosp.minicom -C $LOGFILE
