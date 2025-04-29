FROM openjdk:8-bullseye

ARG HBASE_VERSION=2.3.7
ARG HBASE_URL="https://archive.apache.org/dist/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz"

ENV HBASE_VERSION="$HBASE_VERSION" \
    HBASE_HOME=/opt/hbase \
    HBASE_CONF_DIR=/etc/hbase \
    HBASE_LOG_DIR=/var/log/hbase \
    HBASE_PID_DIR=/var/run/hbase \
    HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_DATA___DIR=/var/lib/zookeeper \
    HBASE_SITE_HBASE_ROOTDIR=/var/lib/hbase

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
    mkdir -p "$HBASE_LOG_DIR" "$HBASE_PID_DIR" "$HBASE_SITE_HBASE_ROOTDIR" "$HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_DATA___DIR" && \
    chown hbase:hadoop -R "$HBASE_LOG_DIR" "$HBASE_PID_DIR" "$HBASE_SITE_HBASE_ROOTDIR" "$HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_DATA___DIR"

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    net-tools \
    netcat \
    socat \
    wait-for-it && \
    rm -rf /var/lib/apt/lists

ENV PATH="$HBASE_HOME/bin:$PATH" \
    HBASE_MANAGES_ZK=true \
    HBASE_COMMAND=master \
    HBASE_RUN_AS=hbase \
    HBASE_ENV_FILE= \
    HBASE_ENV_FILE_WAIT=10 \
    HBASE_HEALTHCHECK_EXPECTED_STATUS='1 active master, 0 backup masters, 1 servers, 0 dead' \
    HBASE_PORT_MAPPINGS= \
    HBASE_HEALTHCHECK_PORT=17000 \
    HBASE_BACKGROUND_PIDS_FILE=/var/run/hbase2-docker.pids \
    HBASE_SECURITY_LOGGER=INFO,console \
    # core settings
    HBASE_SITE_HBASE_CLUSTER_DISTRIBUTED=false \
    HBASE_SITE_HBASE_UNSAFE_STREAM_CAPABILITY_ENFORCE=false \
    # master settings
    HBASE_SITE_HBASE_MASTER_IPC_ADDRESS=0.0.0.0 \
    HBASE_SITE_HBASE_MASTER_HOSTNAME=localhost \
    HBASE_SITE_HBASE_MASTER_PORT=16000 \
    HBASE_SITE_HBASE_MASTER=localhost:16000 \
    HBASE_SITE_HBASE_MASTER_INFO_PORT=16010 \
    # region server settings
    HBASE_SITE_HBASE_REGIONSERVER_IPC_ADDRESS=0.0.0.0 \
    HBASE_SITE_HBASE_REGIONSERVER_HOSTNAME=localhost \
    HBASE_SITE_HBASE_REGIONSERVER_PORT=16020 \
    HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT=16030 \
    # zookeeper settings
    HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT=2181 \
    HBASE_SITE_HBASE_ZOOKEEPER_QUORUM=localhost:2181 \
    # client settings
    HBASE_SITE_HBASE_CLIENT_OPERATION_TIMEOUT=8000 \
    HBASE_SITE_HBASE_RPC_TIMEOUT=200 \
    HBASE_SITE_HBASE_CLIENT_RETRIES_NUMBER=3 \
    HBASE_SITE_ZOOKEEPER_SESSION_TIMEOUT=2000 \
    HBASE_SITE_ZOOKEEPER_RECOVERY_RETRY=3 \
    HBASE_SITE_HBASE_CLIENT_PAUSE=100 \
    # policy settings
    HBASE_POLICY_SECURITY_CLIENT_PROTOCOL_ACL=* \
    HBASE_POLICY_SECURITY_ADMIN_PROTOCOL_ACL=* \
    HBASE_POLICY_SECURITY_MASTERREGION_PROTOCOL_ACL=*

COPY ./conf/ "$HBASE_CONF_DIR/"
COPY ./bin/* /bin/
COPY ./docker-entrypoint-init.d /docker-entrypoint-init.d/
COPY ./docker-entrypoint.sh /

WORKDIR "$HBASE_HOME"
STOPSIGNAL SIGINT

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "hbase2-docker-start" ]

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
