# Tools for Akebi96 Platform Build

This repository provides tools and scripts which helps user to build platform binaries for Akebi96. This contains following tools.

- Docker based build environment and tftp server
- Build Shell scripts
- Minicom scripts for boot and installation via TFTP

## Recommended Instruction to Create/Install AOSP

Here is the recommended instruction of create and install AOSP using these tools.

### Prepare Tools

At first, please make a working directory where clone or download this tool. Recommended directory is `$HOME/linaro` since the user in the docker image is `linaro`. But of course you can choose your favorate directory.
And download this tool as below.

```
mkdir ~/linaro
cd ~/linaro
git clone https://github.com/96boards-akebi96/akebi96-tools.git
```

### Instruction to create docker image

Next, create docker image for build environment and tftp server.

```
cd ~/linaro/akebi96-tools/docker
./build.sh
```

This may take an hour to download cross-build tools.
See docker/README.md for more deteils.

### Instruction to create AOSP image

After creating docker image, you need to run the build-environment container by start-buildenv.sh script. Then you will login on the bash in the container.

```
./start-buildenv.sh
linaro@akebi96-dev:~$ 
```

Note that if you changed the home directory from ~/linaro, you have to pass the new directory to `start-buildenv.sh` by `-h <DIR>` option.

To build AOSP image, run `scripts/build-akebi96.sh` script in the container.

```
linaro@akebi96-dev:~$ akebi96-tools/scripts/build-akebi96.sh
```

Then the script starts downloading required source code repositories and build it automatically. If it successfully run, you will see the build results in `~/linaro/aosp/tftpboot/`.

### Instruction to create boot firmware image

Optionally, you can build Akebi96 boot firmware (Trusted Firmware, OP-TEE, and U-Boot) too. This must be done after building AOSP, because we have to reuse OP-TEE OS which has been built with AOSP image.

To build boot firmware image, run `scripts/build-akebi96-firmware.sh` in the container.

```
linaro@akebi96-dev:~$ akebi96-tools/scripts/build-akebi96-firmware.sh
```

After that, please exit the container by `exit` command.

### Instruction to flash AOSP image

As a standard process, we recommend you to flash the image via TFTP, because USB-gadget interface on Akebi96 is slower than Ethernet interface on the board.

To setup the tftp server, it is easy to use tftpserver container to start tftp server.

```
cd ~/linaro/akebi96-tools/docker
./start-tftpd.sh ~/linaro/aosp/tftpboot/
```

After setup the tftp server, you have to find the tftp server IP address, gateway address, netmask, and the board address, and write it to config file for minicom script.
For example, if your network config is below;

- network mask is 255.255.255.0
- Gateway address is 192.168.1.1
- TFTP server uses 192.168.1.10
- Board IP will be 192.168.1.120

And the ttyUSB0 is connected to Akebi96.

Please make a configuration file as below, and save it as `akebi96-minicom.config`

```
SERVER_IP=192.168.1.10
BOARD_IP=192.168.1.120
GATEWAY_IP=192.168.1.1
NETMASK=255.255.255.0
MINICOM_OPT="-D /dev/ttyUSB0"
```

Make sure your Akebi96 power cable, ethernet cable and USB-serial cable are connected correctly, and run the `akebi96-tftp-aosp.sh` as below.

```
~/linaro/akebi96-tools/minicom/akebi96-tftp-aosp.sh -c akebi96-minicom.config
```

And then turn on the Akebi96 board. It should start the minicom script automatically and try to install AOSP on the board.

NOTE that if you want to install the boot firmware too, pass `firmware` to the `akebi96-tftp-aosp.sh` script as below.

```
~/linaro/akebi96-tools/minicom/akebi96-tftp-aosp.sh -c akebi96-minicom.config firmware
```

This installs both of AOSP and boot firmware.

