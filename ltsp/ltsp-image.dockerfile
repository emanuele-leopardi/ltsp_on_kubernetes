FROM basesystem as ltsp-image

# Retrieve kernel modules
COPY --from=builder /opt/ltsp/amd64/modules.tar.gz /opt/ltsp/amd64/modules.tar.gz

# Install kernel modules
RUN ltsp-chroot sh -c \
    ' export KERNEL="$(ls -1t /usr/src/ | grep -m1 "^linux-headers" | sed "s/^linux-headers-//g")" \
   && tar xpzf /modules.tar.gz \
   && depmod -a "${KERNEL}" \
   && rm -f /modules.tar.gz'

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