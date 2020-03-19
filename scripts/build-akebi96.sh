#!/bin/bash
# SPDX-License-Identifier: MIT

# Build AOSP, Kernel and Drivers

usage(){ # error-message
  echo "$0: Build script for Akebi96 AOSP, Kernel and Drivers"
  [ "$1" ] && echo "ERROR: $1"
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "	-c CONFIG, --config=CONFIG      Use CONFIG file"
  echo "	--sync          Sync the source code"
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
  --no-aosp)
    NO_AOSP=1;;
  --only-aosp)
    ONLY_AOSP=1;;
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
KBIN_DIR=${KBIN_DIR:-${TOPDIR}/kernel-build}
ANDR_DIR=${ANDR_DIR:-${TOPDIR}/android}
IMG_DIR=${IMG_DIR:-${TOPDIR}/images}
TFTP_DIR=${TFTP_DIR:-${TOPDIR}/tftpboot}

### Repositories

AKEBI96_PRJ=${AKEBI96_PRJ:-https://github.com/96boards-akebi96}

KSRC_URL=${KSRC_URL:-${AKEBI96_PRJ}/linux.git}
KSRC_TAG=${KSRC_TAG:-unph-android-v4.19-testing}
CFG_URL=${CFG_URL:-${AKEBI96_PRJ}/akebi96-configs.git}
CFG_TAG=${CFG_TAG:-master}
ACFG_URL=${ACFG_URL:-https://android.googlesource.com/kernel/configs}
ACFG_TAG=${ACFG_TAG:-master}
WIFI_URL=${WIFI_URL:-${AKEBI96_PRJ}/rtl8822bu.git}
WIFI_TAG=${WIFI_TAG:-akebi96}
BT_URL=${BT_URL:-${AKEBI96_PRJ}/rtk_btusb.git}
BT_TAG=${BT_TAG:-master}
VOCD_URL=${VOCD_URL:-${AKEBI96_PRJ}/kmod-video-out.git}
VOCD_TAG=${VOCD_TAG:-master}
MALI_URL=${MALI_URL:-${AKEBI96_PRJ}/mali-kbase.git}
MALI_TAG=${MALI_TAG:-akebi96/r28p0}

MANIFEST_URL=${MANIFEST_URL:-${AKEBI96_PRJ}/akebi96-manifests.git}
MANIFEST_TAG=${MANIFEST_TAG:-master}
AOSP_URL=${AOSP_URL:-https://android.googlesource.com/platform/manifest}
AOSP_TAG=${AOSP_TAG:-master}

### Other configs
JOBS=${JOBS:-`getconf _NPROCESSORS_ONLN`}
SYNC_JOBS=${SYNC_JOBS:-$JOBS} # Number of jobs for repo-sync: depends on network bandwidth
REPO_JOBS=${REPO_JOBS:-$JOBS} # Number of jobs for repo-make: depends on memory size (0.5GB/JOB)
SYNC_GIT=${SYNC_GIT:-0}
NO_AOSP=${NO_AOSP:-0}
ONLY_AOSP=${ONLY_AOSP:-0}
KMENUCONFIG=${KMENUCONFIG:-0}
OPT_KCONFIG=${OPT_KCONFIG:-}

## Preparation
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p $KBIN_DIR $ANDR_DIR $IMG_DIR $TFTP_DIR

## Download Kernel and Drivers

### Clone the repository and define ${PREFIX}_DIR variable
git_clone() { # PREFIX
  eval "_TMP=\$${1}_URL"
  _TMP=${_TMP##*/}
  _TMP=${_TMP%.git}
  eval "${1}_DIR=${TOPDIR}/${_TMP}"
  if [ ! -d ${TOPDIR}/${_TMP} ]; then
    eval "git clone -b \$${1}_TAG --single-branch \$${1}_URL \$${1}_DIR"
  elif [ $SYNC_GIT -eq 1 ]; then
    (eval "cd \$${1}_DIR"
     eval "git fetch origin \$${1}_TAG"
     eval "git reset --hard origin/\$${1}_TAG")
  fi
}


cd $TOPDIR
git_clone KSRC
git_clone CFG
git_clone ACFG
git_clone WIFI
git_clone BT
git_clone VOCD
git_clone MALI

if [ $ONLY_AOSP -ne 1 ]; then

## Build 4.19 kernel

cd $KSRC_DIR
export KCONFIG_CONFIG=${KBIN_DIR}/.config

make O=$KBIN_DIR defconfig
./scripts/kconfig/merge_config.sh -m ${KCONFIG_CONFIG} \
	${CFG_DIR}/linux/akebi96-base.config \
	${ACFG_DIR}/android-4.19/android-base.config \
	${ACFG_DIR}/android-4.19/android-recommended.config \
	${ACFG_DIR}/android-4.19/android-recommended-arm64.config \
	${CFG_DIR}/linux/akebi96-aosp-vendor.config ${OPT_KCONFIG}
make O=$KBIN_DIR olddefconfig
[ $KMENUCONFIG -ne 0 ] && make O=$KBIN_DIR menuconfig
GITHASH=$(git log -n 1 --format="%h")
echo "# $GITHASH" >> ${KCONFIG_CONFIG}

BUILD_KERNEL=$(git diff | wc -l)
if [ $BUILD_KERNEL -eq 0 ] ; then
  if [ -f ${IMG_DIR}/kconfig ]; then
    BUILD_KERNEL=$(diff ${IMG_DIR}/kconfig ${KCONFIG_CONFIG} | wc -l)
  else
    BUILD_KERNEL=1
  fi
fi

if [ $BUILD_KERNEL -ne 0 ] ; then
  make O=$KBIN_DIR -j $JOBS Image socionext/uniphier-ld20-akebi96.dtb
  cp ${KBIN_DIR}/arch/arm64/boot/Image \
     ${KBIN_DIR}/arch/arm64/boot/dts/socionext/uniphier-ld20-akebi96.dtb \
     $IMG_DIR
  echo "# $GITHASH" >> ${KCONFIG_CONFIG}
  cp ${KCONFIG_CONFIG} ${IMG_DIR}/kconfig
fi

export KVER=`make O=$KBIN_DIR -s kernelrelease`

### Build out-of-tree drivers

cd $WIFI_DIR
make KSRC=$KSRC_DIR KVER=$KVER O=$KBIN_DIR -j $JOBS
if [ -f rtl8822bu.ko ] ; then
  mv rtl8822bu.ko 8822bu.ko
fi
cp 8822bu.ko $IMG_DIR

cd $BT_DIR
make KERNEL_DIR=$KSRC_DIR O=$KBIN_DIR KBUILD=$KBIN_DIR -j $JOBS
cp rtk_btusb_core.ko $IMG_DIR/rtk_btusb.ko

cd $VOCD_DIR
make modules KERNEL_DIR=${KBIN_DIR} -j $JOBS
cp vocdrv_ld20/vocdrv-ld20.ko $IMG_DIR

cd $MALI_DIR
make KERNEL_DIR=${KSRC_DIR} MAKETOP=$IMG_DIR O=${KBIN_DIR} modules -j  $JOBS
cp drivers/gpu/arm/midgard/mali_kbase.ko $IMG_DIR

fi ## !ONLY_AOSP

if [ $NO_AOSP -ne 0 ]; then
   echo "Skip building AOSP"
   ls -l $IMG_DIR
   exit 0
fi

# Build AOSP9
## Download AOSP 9

git_clone MANIFEST

cd $ANDR_DIR
if [ ! -d .repo ]; then
  repo init -u $AOSP_URL -b $AOSP_TAG
  cp $MANIFEST_DIR/akebi96.xml .repo/manifests/
  SYNC_GIT=1
elif [ $SYNC_GIT -eq 1 ]; then
  cp $MANIFEST_DIR/akebi96.xml .repo/manifests/
fi

### Sync AOSP 9
if [ $SYNC_GIT -eq 1 ]; then
  repo sync --force-sync -j $SYNC_JOBS -m akebi96.xml
fi

## Build AOSP with new kernels

cd $ANDR_DIR
### Update prebuild binaries
cp ${IMG_DIR}/Image ${IMG_DIR}/uniphier-ld20-akebi96.dtb \
   ${IMG_DIR}/8822bu.ko ${IMG_DIR}/rtk_btusb.ko ${IMG_DIR}/mali_kbase.ko \
   ${IMG_DIR}/vocdrv-ld20.ko \
   device/linaro/akebi96/copy/
mkdir -p device/linaro/akebi96/copy/kernel-headers/asm/
cp ${VOCD_DIR}/vocdrv_ld20/vocd_driver.h \
   device/linaro/akebi96/copy/kernel-headers/asm/

### Build AOSP

export ARCH=arm
source build/envsetup.sh
lunch akebi96-userdebug
make -j $REPO_JOBS

## Split system.img into less than 512MB

cd out/target/product/akebi96/

simg2img system.img system-raw.img
split -d -b 512M system-raw.img _system.img
rm system-raw.img
for img in _system.img* ; do
  img2simg $img ${img#_}
  rm $img
  gzip -f ${img#_}
done

## Copy images to TFTP directory
cp boot_fat_sparse.img system.img*.gz userdata.img vendor.img $TFTP_DIR

