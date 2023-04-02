FROM openjdk:8-bullseye

ARG HBASE_VERSION=2.0.2
ARG HBASE_URL="https://archive.apache.org/dist/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz"

ENV HBASE_VERSION="$HBASE_VERSION" \
    HBASE_HOME=/opt/hbase \
    HBASE_CONF_DIR=/etc/hbase \
    HBASE_LOG_DIR=/var/log/hbase \
    HBASE_PID_DIR=/var/run/hbase \
    HBASE_SITE_hbase_zookeeper_property_dataDir=/var/lib/zookeeper \
    HBASE_SITE_hbase_rootdir=/var/lib/hbase

WORKDIR /tmp
RUN set -ux && \
    # extracting to /opt/hbase
    curl -fSL "$HBASE_URL" -o hbase.tar.gz && \
    tar -xf hbase.tar.gz && \
    mv "hbase-$HBASE_VERSION/" "$HBASE_HOME" && \
    rm -f hbase.tar.gz && \
    # config paths
    rm -rf "$HBASE_HOME/conf" && \
    ln -s "$HBASE_CONF_DIR" "$HBASE_HOME/conf" && \
    # hbase:hadoop user:group and permissions
    addgroup --system hadoop && \
    useradd --system --no-create-home --shell=/bin/false --gid hadoop hbase && \
    mkdir -p "$HBASE_LOG_DIR" "$HBASE_PID_DIR" "$HBASE_SITE_hbase_rootdir" "$HBASE_SITE_hbase_zookeeper_property_dataDir" && \
    chown hbase:hadoop -R "$HBASE_LOG_DIR" "$HBASE_PID_DIR" "$HBASE_SITE_hbase_rootdir" "$HBASE_SITE_hbase_zookeeper_property_dataDir"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        net-tools=1.60+git20181103.0eebece-1 \
        netcat=1.10-46 \
        socat=1.7.4.1-3 && \
    rm -rf /var/lib/apt/lists

ENV HBASE_MANAGES_ZK=true \
    HBASE_COMMAND=master \
    HBASE_RUN_AS=hbase \
    HBASE_ENV_FILE= \
    HBASE_HEALTHCHECK_ENABLED=true \
    HBASE_SECURITY_LOGGER=INFO,console \
    # core settings
    HBASE_SITE_hbase_cluster_distributed=false \
    HBASE_SITE_hbase_unsafe_stream_capability_enforce=false \
    # master settings
    HBASE_SITE_hbase_master_ipc_address=0.0.0.0 \
    HBASE_SITE_hbase_master_hostname=localhost \
    HBASE_SITE_hbase_master_port=16000 \
    HBASE_SITE_hbase_master_info_port=16010 \
    # region server settings
    HBASE_SITE_hbase_regionserver_ipc_address=0.0.0.0 \
    HBASE_SITE_hbase_regionserver_hostname=localhost \
    HBASE_SITE_hbase_regionserver_port=16020 \
    HBASE_SITE_hbase_regionserver_info_port=16030 \
    # zookeeper settings
    HBASE_SITE_hbase_zookeeper_property_clientPort=2181 \
    HBASE_SITE_hbase_zookeeper_peerport=2888 \
    HBASE_SITE_hbase_zookeeper_leaderport=3888 \
    # client settings
    HBASE_SITE_hbase_client_operation_timeout=2000 \
    HBASE_SITE_hbase_rpc_timeout=500 \
    HBASE_SITE_hbase_client_retries_number=2 \
    HBASE_SITE_zookeeper_session_timeout=1000 \
    HBASE_SITE_zookeeper_recovery_retry=2 \
    HBASE_SITE_hbase_client_pause=100 \
    # policy settings
    HBASE_POLICY_security_client_protocol_acl=* \
    HBASE_POLICY_security_admin_protocol_acl=* \
    HBASE_POLICY_security_masterregion_protocol_acl=*

ENV HBASE_SITE_hbase_master="$HBASE_SITE_hbase_master_hostname:$HBASE_SITE_hbase_master_port" \
    HBASE_SITE_hbase_zookeeper_quorum="$HBASE_SITE_hbase_master_hostname:$HBASE_SITE_hbase_zookeeper_property_clientPort"

COPY ./conf/ "$HBASE_CONF_DIR/"
COPY ./bin/* /bin/
COPY ./docker-entrypoint.sh /

WORKDIR "$HBASE_HOME"
STOPSIGNAL SIGINT

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/bin/sh", "-c", "exec bin/hbase \"$HBASE_COMMAND\" start" ]
HEALTHCHECK --interval=20s --timeout=10s --start-period=30s --retries=3 CMD [ "hbase-health-check" ]

ARG BUILD_DATE
ARG BUILD_VERSION
ARG IMAGE_TAG

LABEL maintainer="Diógenes Oliveira <diogenes1oliveira@gmail.com>" \
    org.opencontainers.image.title="diogenes1oliveira/hbase2-docker" \
    org.opencontainers.image.description="Dockerized HBase 2 for use in tests" \
    org.opencontainers.image.authors="Diógenes Oliveira <diogenes1oliveira@gmail.com>" \
    org.opencontainers.image.documentation="https://github.com/diogenes1oliveira/hbase2-docker/blob/main/README.md" \
    org.opencontainers.image.version="$IMAGE_TAG" \
    org.opencontainers.image.url="https://github.com/diogenes1oliveira/hbase2-docker" \
    org.opencontainers.image.source="https://github.com/diogenes1oliveira/hbase2-docker.git" \
    org.opencontainers.image.revision="$BUILD_VERSION" \
    org.opencontainers.image.created="$BUILD_DATE"
