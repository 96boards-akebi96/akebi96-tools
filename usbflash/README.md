Akebi96 USB Recovery Script
---------------------------

This is a U-Boot script for recoverying or updating AOSP image and/or boot firmware image from USB flash drive (mass-storage) device.  (We call it 'recovery', but you can use this for updating your build image)

This script can be used from Akebi96 recovery mode. When you build your custom AOSP image for Akebi96 board, you can use this script for updating the board, instead of TFTP etc.

# Instructions

## Prerequisites

To build this script as an image, you need to install 'mkimage' command.

## Build Script Image

Since U-Boot can not use text script file directly, you need to make an image from the text script file. Run make command.

```
$ make
```

Then you'll see 'recovery.scr' image file.

## Prepare a USB Flash Drive

Prepare a USB flash drive Device, the required size depends on AOSP image but it might be 1GB or so. Format it with VFAT filesystem and mount it to somewhere, for example /mnt.

## Copy the Script

You have to make 'boot' and 'images' directory on the device, those are used for firmware and AOSP images respectively. And copy the script on top directory of the device as below.

```
$ mkdir /mnt/boot /mnt/images
$ cp recovery.scr /mnt/
```

## Copy Firmware Images

Copy the boot firmware images under 'boot' if you have.
If there are no images, the recovery script can just skip it.

```
$ cd ~/linaro/aosp/tftpboot
$ cp uniphir_bl.bin fip.bin boot_voc_ld20.bin /mnt/boot/
```

## Copy AOSP Images

Copy the AOSP images under 'images' if you have.
If there are no images, the recovery script can just skip it.

```
$ cd ~/linaro/aosp/tftpboot
$ cp boot*.img system.img* userdata.img vendor.img /mnt/images/
```

## Recovery Instruction

To recovery from the USB flash drive, follow this instruction.

1. Power off the Akebi96 board.
2. Plug the USB flash drive to USB port (either one is OK)
3. Close 'J1000' Jumper pin.
4. Power on the board.

Then the recovery firmware will update the board images from the USB flash drive device.  After installation is finished, open the 'J1000' jumper and reboot it.

