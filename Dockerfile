FROM openjdk:8

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
    tar -xvf /tmp/hbase.tar.gz -C /opt/ && \
    rm /tmp/hbase.tar.gz* && \
    ln -s /opt/hbase-${HBASE_VERSION}/conf /etc/hbase && \
    ln -s /opt/hbase-${HBASE_VERSION} /opt/hbase-current && \
    mkdir /opt/hbase-${HBASE_VERSION}/logs && \
    mkdir /hadoop-data

ENV HBASE_PREFIX=/opt/hbase-current
ENV HBASE_CONF_DIR=/etc/hbase \
    PATH="${HBASE_PREFIX}/bin/:${PATH}" \
    USER=root

COPY ./bin/* /bin/
WORKDIR ${HBASE_PREFIX}
STOPSIGNAL SIGINT

ENTRYPOINT [ "/bin/docker-entrypoint.sh" ]
CMD [ "hbase-run-foreground.sh" ]
