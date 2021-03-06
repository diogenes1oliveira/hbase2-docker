# hbase2-docker

[![Build Status](https://github.com/diogenes1oliveira/hbase2-docker/actions/workflows/main.yml/badge.svg)](https://github.com/diogenes1oliveira/hbase2-docker/actions)
[![Docker Hub](https://img.shields.io/docker/v/diogenes1oliveira/hbase2-docker)](https://hub.docker.com/r/diogenes1oliveira)
[![License](https://img.shields.io/github/license/diogenes1oliveira/hbase2-docker)](https://github.com/diogenes1oliveira/hbase2-docker/blob/main/LICENSE)

Dockerized HBase 2 for use in tests

## About

Dockerizing HBase is traditionally a quite tricky task because of its sensitivity towards
ports, specific hostnames, not to mention insufficient official documentation. The common
advice is to just run the standalone mode locally or update the `/etc/hosts` when running
in a Docker container. Which, of course, doesn't help either if you want to run in the
distributed mode.

Here I implement a Docker image and a docker-compose distributed cluster to make this
method easier:

- The standalone mode binds to `localhost`, so local application development defaults
  will work without hiss;
- The cluster stack binds to `*.localhost` hostnames, so in most Linuxes this will
  work properly without even setting up the `/etc/hosts`;
- The ports are configurable and properly limited;
- Running within Docker will assure proper isolation and cleanup of logs and other
  temporary files;
- We can set HBase configuration with `$HBASE_CONF_*` environment variables instead of
  having to fiddle around with XMLs.

This stack is mostly based on the repository https://github.com/big-data-europe/docker-hbase.

## Running

### Standalone mode

You can run a standalone HBase container directly via `docker run`:

```shell
$ docker run -it --rm \
    -p 2181:2181 -p 16000:16000 -p 16010:16010 -p 16020:16020 -p 16030:16030 \
    diogenes1oliveira/hbase2-docker:1.0.0-hbase2.0.2
```

Or you can use the convenience Makefile to start and stop it:

```shell
$ make start
$ make kill
```

The command above will start a standalone HBase cluster with all the necessary ports
bound to the local interface and with all hostnames bound and advertised to `localhost`.

To get more details about the standalone mode, check https://hbase.apache.org/book.html#standalone.

### Cluster Mode

You can run a full Hadoop and HBase cluster using the included [docker-compose.yml](./docker-compose.yml).

```shell
$ make cluster/up
$ make cluster/rm
```

The stack binds and advertises the following hostnames:

- **Master**: `hbase-master.localhost`
- **Region Server**: `hbase-region1.localhost`
- **ZooKeeper**: `zookeeper.localhost`

In most Linuxes any `.localhost` host resolves to `127.0.0.1`, so if this is not your case,
you'll have to update the `/etc/hosts` manually.

To get more details about the cluster mode, check https://hbase.apache.org/book.html#fully_dist.

### Configuration

The [entrypoint](./bin/docker-entrypoint.sh) script maps environment variables with the prefix
`HBASE_CONF_` by removing the prefix and replacing dots by underscores:

```xml
<!-- HBASE_CONF_some_config=value -->
<property>
    <name>some.config</name>
    <value>value</value>
</property>
```

The default configuration set [hbase-config-build.sh](./bin/hbase-config-build.sh) is as such:

| Name                                     | Default value                             | Role |
| ---------------------------------------- | ----------------------------------------- | ---- |
| `$HBASE_ROLE`                            | `standalone`                              |      |
| `$HBASE_MANAGES_ZK`                      | `true` if standalone, else `false`        |      |
| `hbase.rootdir`                          | `/data/hbase`                             | all  |
| `hbase.unsafe.stream.capability.enforce` | `false` if standalone, else `true`        |      |
| `hbase.cluster.distributed`              | `false` if standalone, else `true`        |      |
| `hbase.zookeeper.property.dataDir`       | `/data/zookeeper` if standalone           |      |
| `hbase.zookeeper.peerport`               | `2888`                                    |      |
| `hbase.zookeeper.leaderport`             | `3888`                                    |      |
| `hbase.zookeeper.property.clientPort`    | `2181`                                    |      |
| `hbase.master.ipc.address`               | `0.0.0.0`                                 |      |
| `hbase.regionserver.ipc.address`         | `0.0.0.0` if regionserver or standalone   |      |
| `hbase.master.hostname`                  | `localhost`                               |      |
| `hbase.master.port`                      | `16000`                                   |      |
| `hbase.master.info.port`                 | `16010`                                   |      |
| `hbase.regionserver.hostname`            | `localhost` if regionserver or standalone |      |
| `hbase.regionserver.port`                | `16020` if regionserver or standalone     |      |
| `hbase.regionserver.info.port`           | `160030` if regionserver or standalone    |      |

Additionally, the following configs are built by the [entrypoint](./docker-entrypoint.sh):

| Name                     | Default value                                                     |
| ------------------------ | ----------------------------------------------------------------- |
| `hbase.master`           | `${hbase.master.hostname}:${hbase.master.port}`                   |
| `hbase.zookeeper.quorum` | `${hbase.master.hostname}:${hbase.zookeeper.property.clientPort}` |

### Configuring binding ports

Configurations of ports are specially sensitive to HBase. If you're going to change
them, be sure to:

- You have to bind the same ports both inside and outside Docker itself in `-p PORT:PORT`;
- Set the same port in the environment variable `$HBASE_CONF_..._port`.

### Configuring hostnames

Configurations of hostnames are specially sensitive to HBase and the containers need to be
accessible both inside and outside Docker with the same hostname. By default the container
binds them all to `localhost`, so if you're going to change any of them, be sure to:

- The new hostname maps locally to `127.0.0.1` via `/etc/hosts` or `resolv.conf`;
- The same hostname is accessible inside the container via `--add-host HOSTNAME:127.0.0.1`;
- Set the same hostname in the environment variable `$HBASE_CONF_..._port`.

## Development

The following build variables are available. Be sure to set them consistently when
executing multiple `make` commands:

| Variable           | Default                                                         | Description                  |
| ------------------ | --------------------------------------------------------------- | ---------------------------- |
| `IMAGE_BASENAME`   | Extracted from the label `org.opencontainers.image.title`       | Image basename               |
| `HBASE_VERSION`    | `2.0.2`                                                         | HBase version                |
| `VCS_REF`          | `1.0.0`                                                         | Git tag, commit ID or branch |
| `BUILD_VERSION`    | `${VCS_REF}-hbase${HBASE_VERSION}`                              | Image tag                    |
| `BUILD_DATE`       | `1970-01-01T00:00:00Z`                                          | Current UTC timestamp        |
| `REPO_HOME`        | Extracted from the label `org.opencontainers.image.url`         | Repository HTTP(S) URL       |
| `REPO_DESCRIPTION` | Extracted from the label `org.opencontainers.image.description` | Repository description       |

Of course, you can also directly run `docker build` and `docker push`, but then you'll
have to set the build arguments directly. Check the aforementioned [Makefile](./Makefile)
for more details.

### Linting and Testing

To run [hadolint](https://github.com/hadolint/hadolint) against the Dockerfile
and [shellcheck](https://github.com/koalaman/shellcheck) against the shell scripts:

```shell
$ make lint
```

To run the [bats](https://github.com/bats-core/bats-core) tests:

```
$ make test
```

### Building and Pushing

Use the phony target `build` in the [Makefile](./Makefile) to build the Docker
image:

```shell
$ make build VCS_REF=some-git-tag
```

To push to the Docker registry:

```shell
$ make push VCS_REF=some-git-tag
```

To update the description in the Docker Hub:

```
$ make readme/push
```
