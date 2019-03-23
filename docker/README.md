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

### Build Environment
For build-environment, run `run.sh -h <working-homedir>`. Here the working-homedir is for container to mount the directory as the home directory of pseudo user (linaro) in the container. The <working-homedir>/aosp/ is used for build space.
If you ommit specifying the working-homedir, it will use "~/linaro" automatically.

### TFTP server

Run `start-tftpd.sh <tftpboot-directory>` to launch tftpd.

#### Firewall Troubleshoot

If you have any trouble to connect to TFTP server, you may have to setup your network firewall service carefully.

1. At first you might have to load `nf_conntrack_tftp` kernel module by `modprobe nf_conntrack_tftp`.
  (Maybe you'd better configure it to autoload, e.g.: `echo "nf_conntrack_tftp" >> /etc/modules-load.d/modules.conf` )
2. Run `ufw allow from 192.168.XX.0/24 to any proto udp port 69` to add new rule. Please replace `192.168.XX.0/24` to your network address.

Or if you are using firewalld, you just need to run `firewall-cmd --add-service=tftp --permanent` to add a rule.

#### Another Tips

- If you install microk8s by snap, it also makes a firewall like rules on iptables. I don't recommend you to try using microk8s (or any other distributed system) with local docker.

- If you are testing it with another linux machine, please check the firewall on that machine. (tcpdump the docker0 and if you see any "icmp ... admin prohibited filter" like message, that might come from client or FW in between client and host.

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

And run start-buildenv.sh for launching build environment.

```
./start-buildenv.sh
```
