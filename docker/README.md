# Docker based Build Environment for Akebi96

This provides a dockerfile to build a container image for
non-root user-level build environment.

## How to Build

Run `build.sh`. This will make akebi96-dev and tftp docker images in local.
Note that akebi96-dev image is customized for current user. So each user has to run it to build.
When successfully finished, you will see following images.

- akebi96-dev:latest
- akebi96-dev:<your-UID>-8.2-2019.01
- akebi96-dev:<commit-hash>
- tftp:latest
- tftp:<commit-hash>

## How to Run

Run `start-tftpd.sh <tftpboot-directory>` to launch tftpd.

For build-environment, run `run.sh -h <working-homedir>`. Here the working-homedir is for container to mount the directory as the home directory of pseudo user (linaro) in the container. The <working-homedir>/aosp/ is used for build space.
If you ommit specifying the working-homedir, it will use "~/linaro" automatically.

## Recommended Usage

Please clone this repository under your working directory. I recommend you to make "~/linaro" and clone this under it.

```
mkdir ~/linaro
cd ~/linaro
git clone -b master https://github.com/96boards-akebi96/akebi96-tools.git
```

And run build.sh, not by super-user, but by the normal user who can run docker.

```
cd akebi96-tools/docker
./build.sh
```

And run run.sh.

```
./run.sh
```

