#!/bin/bash
# SPDX-License-Identifier: MIT

# Build Akebi96 Firmware

usage(){ # error-message
  echo "$0: Build script for Akebi96 Firmware"
  [ "$1" ] && echo "ERROR: $1"
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "	-c CONFIG, --config=CONFIG      Use CONFIG file"
  echo "	--sync          Sync the source code"
  echo "	--no-voc        Do not use VOC firmware"
  echo "	--no-optee      Do not use OP-TEE OS"
  echo "	--no-aosp       Do not use AOSP build OPTEE"
  echo "	--debug         Show executed commands for debug"
  echo "	-h, --help      Show this message"
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
  --no-aosp)
    NO_AOSP=1;;
  --no-optee)
    NO_OPTEE=1;;
  --debug)
    set -x;;
  -h|--help)
    usage ;;
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
ATF_URL=${ATF_URL:-https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git}
ATF_TAG=${ATF_TAG:-master}
OPTEE_URL=${OPTEE_URL:-${AKEBI96_PRJ}/optee_os.git}
OPTEE_TAG=${OPTEE_TAG:-akebi96}

### Other configs
JOBS=${JOBS:-`getconf _NPROCESSORS_ONLN`}
SYNC_GIT=${SYNC_GIT:-0}
NO_VOCFW=${NO_VOCFW:-0}
NO_OPTEE=${NO_OPTEE:-0}
NO_AOSP=${NO_AOSP:-0}

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
[ $NO_AOSP -ne 0 ] && git_clone OPTEE

## Setup Env
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p $ANDR_DIR $IMG_DIR $TFTP_DIR

## Build U-Boot

cd $UBOOT_DIR
make uniphier_v8_defconfig
./scripts/kconfig/merge_config.sh -m ./.config ${CFG_DIR}/u-boot/akebi96-aosp.config
make olddefconfig
UBOOT_BUILD=1
if [ $(git diff | wc -l) = 0 ]; then
  GITHASH=$(git log -n 1 --format="%h")
  echo "# $GITHASH" >> .config
  if [ -f $IMG_DIR/uboot.config ]; then
    UBOOT_BUILD=$(diff -u $IMG_DIR/uboot.config .config | wc -l)
  fi
  cp .config $IMG_DIR/uboot.config
fi

if [ $UBOOT_BUILD != 0 ];then
if [ $NO_VOCFW -eq 0 ]; then
  cp ${PREBIN_DIR}/u-boot/uniphier-ld20-aosp.h include/configs/
  make DEVICE_TREE=uniphier-ld20-akebi96 CONFIG_SYS_CONFIG_NAME=uniphier-ld20-aosp
else
  make DEVICE_TREE=uniphier-ld20-akebi96 CONFIG_SYS_CONFIG_NAME=uniphier
fi
cp ./u-boot.bin $IMG_DIR
fi

build_optee() {(
  cd $OPTEE_DIR
  TARGET=ld20
  export CROSS_COMPILE=aarch64-linux-gnu-
  export CROSS_COMPILE_32=arm-linux-gnueabihf-
  make PLATFORM=uniphier-${TARGET} ARCH=arm CFG_ARM64_core=y clean
  make PLATFORM=uniphier-${TARGET} ARCH=arm CFG_ARM64_core=y \
       CROSS_COMPILE_ta_arm64=${CROSS_COMPILE} \
       CROSS_COMPILE_ta_arm32=${CROSS_COMPILE_32} \
       CFG_TEE_CORE_LOG_LEVEL=3 CFG_TEE_TA_LOG_LEVEL=3 \
       -j 4
  )}

## Copy OP-TEE OS from AOSP or Build it from source
if [ $NO_OPTEE -eq 0 ]; then
if [ $NO_AOSP -eq 0 ]; then
  OPTEE_OUT_DIR=${ANDR_DIR}/out/target/product/akebi96/optee/arm-plat-uniphier/core
else
  OPTEE_OUT_DIR=${OPTEE_DIR}/out/arm-plat-uniphier/core
fi
PREBUILT_OPTEE=${OPTEE_OUT_DIR}/tee-pager_v2.bin
if [ ! -f ${PREBUILT_OPTEE} ]; then
  PREBUILT_OPTEE=$OPTEE_OUT_DIR/tee-pager.bin
fi

CURR_OPTEE=${IMG_DIR}/tee-pager.bin

if [ $NO_AOSP -eq 0 ]; then
  if [ ! -f $PREBUILT_OPTEE -a ! -f $CURR_OPTEE ]; then
    echo "ERROR: No OPTEE OS found!"
    exit 1
  fi
  if [ ! -f $CURR_OPTEE -o $PREBUILT_OPTEE -nt $CURR_OPTEE ]; then
    cp -f $PREBUILT_OPTEE $CURR_OPTEE
  fi
else
  build_optee
  cp $PREBUILT_OPTEE $CURR_OPTEE
fi

else
CURR_OPTEE=
fi

## Build Trusted Firmware

cd $ATF_DIR
make PLAT=uniphier realclean
if [ "$CURR_OPTEE" ]; then
make PLAT=uniphier BUILD_PLAT=./build SPD=opteed BL32=$CURR_OPTEE BL33=${IMG_DIR}/u-boot.bin bl2_gzip fip
else
make PLAT=uniphier BUILD_PLAT=./build BL33=${IMG_DIR}/u-boot.bin bl2_gzip fip
fi
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
