#!/bin/bash
# SPDX-License-Identifier: MIT

# Build Akebi96 Firmware

usage(){ # error-message
  echo "$0: Build script for Akebi96 Firmware"
  [ "$1" ] && echo "ERROR: $1"
  echo "Usage: $0 [-c|--config CONFIG_FILE]"
  [ "$1" ] && exit 1
  exit 0
}

set -e

## Parse options

while [ $# -ne 0 ]; do
  case $1 in
  --config|-c)
    BUILD_CONFIG=$2; shift 1;;
  --config=*)
    BUILD_CONFIG=${1#--config=};;
  --sync)
    SYNC_GIT=1;;
  --no-voc)
    NO_VOCFW=1;;
  --debug)
    set -x;;
  *)
    usage "Unrecognized option: $1" ;;
  esac
  shift 1
done

### User custom config
import_config() { # config-file
  . $(dirname $1)/$(basename $1)
}
[ -f "$BUILD_CONFIG" ] && import_config $BUILD_CONFIG

## Default Configurations

### Directories

TOPDIR=${TOPDIR:-~/aosp/}
IMG_DIR=${IMG_DIR:-${TOPDIR}/images}
TFTP_DIR=${TFTP_DIR:-${TOPDIR}/tftpboot}
ANDR_DIR=${ANDR_DIR:-${TOPDIR}/android}

### Repositories

AKEBI96_PRJ=${AKEBI96_PRJ:-https://github.com/96boards-akebi96}

UBL_URL=${UBL_URL:-https://github.com/uniphier/uniphier-bl.git}
UBL_TAG=${UBL_TAG:-master}
CFG_URL=${CFG_URL:-${AKEBI96_PRJ}/akebi96-configs.git}
CFG_TAG=${CFG_TAG:-master}
PREBIN_URL=${PREBIN_URL:-${AKEBI96_PRJ}/akebi96-prebuild.git}
PREBIN_TAG=${PREBIN_TAG:-master}
UBOOT_URL=${UBOOT_URL:-${AKEBI96_PRJ}/u-boot.git}
UBOOT_TAG=${UBOOT_TAG:-akebi96}
ATF_URL=${ATF_URL:-${AKEBI96_PRJ}/arm-trusted-firmware.git}
ATF_TAG=${ATF_TAG:-master}
MBTLS_URL=${MBTLS_URL:-https://github.com/ARMmbed/mbedtls}
MBTLS_TAG=${MBTLS_TAG:-mbedtls-2.4.2}

### Other configs
JOBS=${JOBS:-`getconf _NPROCESSORS_ONLN`}
SYNC_GIT=${SYNC_GIT:-0}
NO_VOCFW=${NO_VOCFW:-0}

## Download Firmware

### Clone the repository and define ${PREFIX}_DIR variable
git_clone() { # PREFIX
  eval "_TMP=\$${1}_URL"
  _TMP=${_TMP##*/}
  _TMP=${_TMP%.git}
  eval "${1}_DIR=${TOPDIR}/${_TMP}"
  if [ ! -d ${TOPDIR}/${_TMP} ]; then
    eval "git clone -b \$${1}_TAG --single-branch \$${1}_URL \$${1}_DIR"
  elif [ $SYNC_GIT -eq 1 ]; then
    eval "cd \$${1}_DIR"
    eval "git fetch origin \$${1}_TAG"
    eval "git reset --hard origin/\$${1}_TAG"
  fi
}

cd $TOPDIR
git_clone UBL
git_clone CFG
[ $NO_VOCFW -eq 0 ] && git_clone PREBIN
git_clone UBOOT
git_clone ATF
git_clone MBTLS

## Setup Env
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p $ANDR_DIR $IMG_DIR $TFTP_DIR

## Build U-Boot

cd $UBOOT_DIR
make uniphier_v8_defconfig
./scripts/kconfig/merge_config.sh -m ./.config ${CFG_DIR}/u-boot/akebi96-aosp.config
make olddefconfig
if [ $NO_VOCFW -eq 0 ]; then
  cp ${PREBIN_DIR}/u-boot/uniphier-ld20-aosp.h include/configs/
  make DEVICE_TREE=uniphier-ld20-akebi96 CONFIG_SYS_CONFIG_NAME=uniphier-ld20-aosp
else
  make DEVICE_TREE=uniphier-ld20-akebi96 CONFIG_SYS_CONFIG_NAME=uniphier
fi
cp ./u-boot.bin $IMG_DIR

## Copy OP-TEE OS from AOSP

AOSP_OPTEE=${ANDR_DIR}/out/target/product/akebi96/optee/arm-plat-uniphier/core/tee-pager.bin
CURR_OPTEE=${IMG_DIR}/tee-pager.bin

if [ ! -f $AOSP_OPTEE -a ! -f $CURR_OPTEE ]; then
  echo "ERROR: No OPTEE OS found!"
  exit 1
fi

if [ ! -f $CURR_OPTEE -o $AOSP_OPTEE -nt $CURR_OPTEE ]; then
  cp -f $AOSP_OPTEE $CURR_OPTEE
fi

## Build Trusted Firmware

cd $ATF_DIR
make PLAT=uniphier realclean
make PLAT=uniphier BUILD_PLAT=./build SPD=opteed BL32=$CURR_OPTEE BL33=${IMG_DIR}/u-boot.bin bl2_gzip fip
cp build/fip.bin build/bl2.bin.gz ${IMG_DIR}

## Build uniphier-bl

cd $UBL_DIR
make all
cat bl_ld20_global.bin ${IMG_DIR}/bl2.bin.gz > ${IMG_DIR}/uniphier_bl.bin

## Copy firmware to TFTP directory

cd ${IMG_DIR}
cp fip.bin uniphier_bl.bin $TFTP_DIR
[ $NO_VOCFW -eq 0 ] && cp ${PREBIN_DIR}/boot_voc_ld20.bin $TFTP_DIR

ls -l $TFTP_DIR
echo "Done."
