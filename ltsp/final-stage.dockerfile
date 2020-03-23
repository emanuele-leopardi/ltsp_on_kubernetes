FROM ltsp-base
COPY --from=ltsp-image /opt/ltsp/images /opt/ltsp/images
COPY --from=ltsp-image /etc/nbd-server/conf.d /etc/nbd-server/conf.d
COPY --from=ltsp-image /var/lib/tftpboot /var/lib/tftpboot