FROM ubuntu:16.04 as ltsp-base

ADD nbd-server-wrapper.sh /bin/
RUN apt-get -y update \
 && apt-get -y install \
      ltsp-server \
      tftpd-hpa \
      nbd-server \
      grub-common \
      grub-pc-bin \
      grub-efi-amd64-bin \
      curl \
 && sed -i 's|in_target mount|in_target_nofail mount|' \
      /usr/share/debootstrap/functions \
  # Add EFI support and Grub bootloader (#1745251)
 && rm -rf /var/lib/apt/lists \
 && apt-get clean

FROM ltsp-base as basesystem

ARG DEBIAN_FRONTEND=noninteractive

# Prepare base system
RUN debootstrap --arch amd64 xenial /opt/ltsp/amd64

# Install updates
RUN echo "\
      deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse\n\
      deb http://archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse\n\
      deb http://archive.ubuntu.com/ubuntu xenial-security main restricted universe multiverse" \
      > /opt/ltsp/amd64/etc/apt/sources.list \
 && ltsp-chroot apt-get -y update \
 && ltsp-chroot apt-get -y upgrade

# Installing LTSP-packages
RUN ltsp-chroot apt-get -y install ltsp-client-core

# Apply initramfs patches
# 1: Read params from /etc/lts.conf during the boot (#1680490)
# 2: Add support for PREINIT variables in lts.conf

# Write new local client config for boot NBD image to ram:
RUN echo "[Default]\nLTSP_NBD_TO_RAM = true" \
      > /opt/ltsp/amd64/etc/lts.conf

# Install packages
RUN echo 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' \
      >> /opt/ltsp/amd64/etc/apt/apt.conf.d/01norecommend \
 && ltsp-chroot apt-get -y install \
      software-properties-common \
      apt-transport-https \
      ca-certificates \
      ssh \
      bridge-utils \
      pv \
      jq \
      vlan \
      bash-completion \
      screen \
      vim \
      mc \
      lm-sensors \
      htop \
      jnettop \
      rsync \
      curl \
      wget \
      tcpdump \
      arping \
      apparmor-utils \
      nfs-common \
      telnet \
      sysstat \
      ipvsadm \
      ipset \
      make

# Install kernel
RUN ltsp-chroot apt-get -y install linux-generic-hwe-16.04

FROM basesystem as ltsp-image

# Install docker
RUN ltsp-chroot sh -c \
   '  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
   && echo "deb https://download.docker.com/linux/ubuntu xenial stable" \
        > /etc/apt/sources.list.d/docker.list \
   && apt-get -y update \
   && apt-get -y install \
        docker-ce=$(apt-cache madison docker-ce | grep 18.06 | head -1 | awk "{print $ 3}")'

# Configure docker options
RUN DOCKER_OPTS="$(echo \
      --storage-driver=overlay2 \
      --iptables=false \
      --ip-masq=false \
      --log-driver=json-file \
      --log-opt=max-size=10m \
      --log-opt=max-file=5 \
      )" \
 && sed "/^ExecStart=/ s|$| $DOCKER_OPTS|g" \
      /opt/ltsp/amd64/lib/systemd/system/docker.service \
      > /opt/ltsp/amd64/etc/systemd/system/docker.service

# Install kubeadm, kubelet and kubectl
RUN ltsp-chroot sh -c \
      '  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
      && echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" \
           > /etc/apt/sources.list.d/kubernetes.list \
      && apt-get -y update \
      && apt-get -y install kubelet kubeadm kubectl cri-tools'

# Disable automatic updates
RUN rm -f /opt/ltsp/amd64/etc/apt/apt.conf.d/20auto-upgrades

# Disable apparmor profiles
RUN ltsp-chroot find /etc/apparmor.d \
      -maxdepth 1 \
      -type f \
      -name "sbin.*" \
      -o -name "usr.*" \
      -exec ln -sf "{}" /etc/apparmor.d/disable/ \;

# Write kernel cmdline options
RUN KERNEL_OPTIONS="$(echo \
      init=/sbin/init-ltsp \
      forcepae \
      console=tty1 \
      console=ttyS0,9600n8 \
      nvme_core.default_ps_max_latency_us=0 \
    )" \
 && sed -i "/^CMDLINE_LINUX_DEFAULT=/ s|=.*|=\"${KERNEL_OPTIONS}\"|" \
      "/opt/ltsp/amd64/etc/ltsp/update-kernels.conf"

# Cleanup caches
RUN rm -rf /opt/ltsp/amd64/var/lib/apt/lists \
 && ltsp-chroot apt-get clean

# Build squashed image
RUN ltsp-update-image

FROM ltsp-base
COPY --from=ltsp-image /opt/ltsp/images /opt/ltsp/images
COPY --from=ltsp-image /etc/nbd-server/conf.d /etc/nbd-server/conf.d
COPY --from=ltsp-image /var/lib/tftpboot /var/lib/tftpboot