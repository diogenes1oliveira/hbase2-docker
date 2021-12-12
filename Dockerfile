FROM openjdk:8-bullseye

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        net-tools=1.60+git20181103.0eebece-1 \
        netcat=1.10-46 && \
    rm -rf /var/lib/apt/lists

ARG HBASE_VERSION
ARG HBASE_URL="https://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
RUN set -x && \
    curl -fSL "${HBASE_URL}" -o /tmp/hbase.tar.gz && \
    curl -fSL "${HBASE_URL}.asc" -o /tmp/hbase.tar.gz.asc && \
    tar -xf /tmp/hbase.tar.gz -C /opt/ && \
    rm /tmp/hbase.tar.gz* && \
    mv /opt/hbase-${HBASE_VERSION} /opt/hbase && \
    mv /opt/hbase/conf /etc/hbase && \
    mkdir -p /var/log/hbase /var/run/hbase /var/lib/hbase /var/lib/zookeeper && \
    addgroup --system hadoop && \
    useradd --system --no-create-home --shell=/bin/false --gid hadoop hbase && \
    chown hbase:hadoop -R /var/log/hbase /var/run/hbase /var/lib/hbase /var/lib/zookeeper

ENV HBASE_HOME=/opt/hbase \
    HBASE_CONF_DIR=/etc/hbase \
    HBASE_LOG_DIR=/var/log/hbase \
    HBASE_PID_DIR=/var/run/hbase \
    HBASE_LOG_OPTS='-Dhbase.log.maxfilesize=1MB -Dhbase.log.maxbackupindex=1 -Dhbase.security.log.maxfilesize=1MB -Dhbase.security.log.maxbackupindex=1' \
    PATH=/opt/hbase/bin:${PATH}

COPY ./bin/* /bin/
WORKDIR ${HBASE_HOME}
STOPSIGNAL SIGINT

ENTRYPOINT [ "/bin/docker-entrypoint.sh" ]

ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_VERSION

LABEL maintainer="Diógenes Oliveira <diogenes1oliveira@gmail.com>" \
    org.opencontainers.image.title="diogenes1oliveira/hbase2-docker" \
    org.opencontainers.image.description="Dockerized HBase 2 for use in tests" \
    org.opencontainers.image.authors="Diógenes Oliveira <diogenes1oliveira@gmail.com>" \
    org.opencontainers.image.documentation="https://github.com/diogenes1oliveira/hbase2-docker/blob/main/README.md" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.url="https://github.com/diogenes1oliveira/hbase2-docker" \
    org.opencontainers.image.source="https://github.com/diogenes1oliveira/hbase2-docker.git" \
    org.opencontainers.image.revision="${VCS_REF}" \
    org.opencontainers.image.created="${BUILD_DATE}"
