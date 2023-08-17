# hbase2-docker

[![Build Status](https://github.com/diogenes1oliveira/hbase2-docker/actions/workflows/main.yml/badge.svg)](https://github.com/diogenes1oliveira/hbase2-docker/actions)
[![Docker Hub](https://img.shields.io/docker/v/diogenes1oliveira/hbase2-docker)](https://hub.docker.com/r/diogenes1oliveira)
[![Maven Central](https://img.shields.io/maven-central/v/io.github.diogenes1oliveira/hbase2-testcontainers?versionPrefix=0.)]([https://google.com](https://mvnrepository.com/artifact/io.github.diogenes1oliveira/hbase2-testcontainers))
[![License](https://img.shields.io/github/license/diogenes1oliveira/hbase2-docker)](https://github.com/diogenes1oliveira/hbase2-docker/blob/main/LICENSE)

Dockerized HBase 2 for use in tests

## About

Dockerizing HBase is traditionally a quite tricky task because of its sensitivity towards
ports, specific hostnames, not to mention insufficient official documentation. The common
advice is to just run the standalone mode locally or manually update the `/etc/hosts` with
the container IP. Which doesn't help either if you want to run in the
distributed mode or if you're not running with the standard local Docker socket in a Linux (e.g., Windows).

Here I implement a Docker image to make this method easier:

- The container binds to `localhost` by default, so local application development defaults
  will work without hiss. You can also export `HBASE2__DOCKER_HOSTNAME=some.other.host` to
  override this;
- The ports are configurable and properly limited. You can also set different ports inside
  and outside the container;
- Running within Docker will assure proper isolation and cleanup of logs and other
  temporary files;
- We can set HBase configuration with `$HBASE_SITE_*` environment variables instead of
  having to fiddle around with XMLs.

This stack was initially based on the repository https://github.com/big-data-europe/docker-hbase.

## Docker image

The Docker image is available in [Docker Hub](https://hub.docker.com/r/diogenes1oliveira/hbase2-docker/).

### Default ports and hostname

You can run a standalone HBase container directly via `docker run`:

```shell
$ docker run -d --rm --name hbase2-docker \
    -p 2181:2181 -p 16000:16000 -p 16010:16010 -p 16020:16020 -p 16030:16030 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

You can also use the [docker-compose.yml](./docker-compose.yml) included in this repo:

```shell
$ docker compose up || docker-compose up
```

The commands above will start a standalone HBase cluster with all the necessary ports
bound to the local interface and with all hostnames advertised to `localhost`.

To get more details about the standalone mode, check https://hbase.apache.org/book.html#standalone.

### Configuration

The configuration is made through environment variables.

#### Process configurations

| Name                                 | Default value                                          | Description                                                                                                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$HBASE_MANAGES_ZK`                  | `true`                                                 | run an embedded zookeeper. required on standalone mode                                                                                                                                                                                |
| `$HBASE_COMMAND`                     | `master`                                               | command to execute (`master`, `regionserver`, etc). The `master` value when in standalone mode executes both `master`and `regionserver` command                                                                                       |
| `$HBASE_RUN_AS`                      | `hbase`                                                | user to run the hbase process as                                                                                                                                                                                                      |
| `$HBASE_ENV_FILE`                    | -                                                      | path to a .env file to be loaded when starting the container                                                                                                                                                                          |
| `$HBASE_ENV_FILE_WAIT`               | `10`                                                   | seconds to wait for the .env to show up within the container                                                                                                                                                                          |
| `$HBASE_HEALTHCHECK_EXPECTED_STATUS` | `1 active master, 0 backup masters, 1 servers, 0 dead` | string to lookup within the `status` command in the healthcheck                                                                                                                                                                       |
| `$HBASE_BACKGROUND_PIDS_FILE`        | `/var/run/hbase2-docker.pids`                          | file containing the PIDs of supporting background processes                                                                                                                                                                           |
| `$HBASE_PORT_MAPPINGS`               | -                                                      | set of comma or whitespace-separated mappings `SOURCE_PORT:TARGET_PORT` to map a source port to another. For each mapping, a background process will be started to direct the TCP traffic reaching the source port to the target port |

#### HBase configurations

The [hadoop-config-from-env](./bin/hadoop-config-from-env) script maps environment variables with the prefix
`HBASE_SITE_` by removing the prefix and replacing dots by underscores. The resulting configurations are saved to `/etc/hbase/hbase-site.xml`
and `/etc/hbase/hbase-site.properties`:

```xml
<!-- HBASE_SITE_some_config=value -->
<property>
    <name>some.config</name>
    <value>value</value>
</property>
```

Core configurations:

| Environment variable name                            | HBase configuration                      | Default value        | Description                                                          |
| ---------------------------------------------------- | ---------------------------------------- | -------------------- | -------------------------------------------------------------------- |
| `$HBASE_SITE_hbase_zookeeper_property_dataDir`       | `hbase.zookeeper.property.dataDir`       | `/var/lib/zookeeper` | path to store the zookeeper data                                     |
| `$HBASE_SITE_hbase_zookeeper_property_clientPort`    | `hbase.zookeeper.property.clientPort`    | `2181`               | port the embedded zookeeper should bind to                           |
| `$HBASE_SITE_hbase_rootdir`                          | `hbase.rootdir`                          | `/var/lib/hbase`     | path to store the HBase data                                         |
| `$HBASE_SITE_hbase_cluster_distributed`              | `hbase.cluster.distributed`              | `false`              | whether to run in standalone mode (`false`) or cluster mode (`true`) |
| `$HBASE_SITE_hbase_unsafe_stream_capability_enforce` | `hbase.unsafe.stream.capability.enforce` | `false`              | set to false if the HBase data is stored in the local filesystem     |
| `$HBASE_SITE_hbase_master_hostname`                  | `hbase.master.hostname`                  | `localhost`          | advertised hostname for the master node                              |
| `$HBASE_SITE_hbase_master_port`                      | `hbase.master.port`                      | `16000`              | advertised port for the master node                                  |
| `$HBASE_SITE_hbase_master`                           | `hbase.master`                           | `localhost:16000`    | advertised address for the master node                               |
| `$HBASE_SITE_hbase_master_info_port`                 | `hbase.master.info.port`                 | `16010`              | port for the master UI interface                                     |
| `$HBASE_SITE_hbase_regionserver_hostname`            | `hbase.regionserver.hostname`            | `localhost`          | advertised hostname for the region server node                       |
| `$HBASE_SITE_hbase_regionserver_port`                | `hbase.regionserver.port`                | `16020`              | advertised port for the region server node                           |
| `$HBASE_SITE_hbase_regionserver_info_port`           | `hbase.regionserver.info.port`           | `16030`              | port for the region server UI interface                              |
| `$HBASE_SITE_hbase_zookeeper_quorum`                 | `hbase.zookeeper.quorum`                 | `localhost:2181`     | comma-separated addresses of the zookeeper cluster                   |

Extra configurations:

| Environment variable name                    | HBase configuration              | Default value |
| -------------------------------------------- | -------------------------------- | ------------- |
| `$HBASE_SITE_hbase_master_ipc_address`       | `hbase.master.ipc.address`       | `0.0.0.0`     |
| `$HBASE_SITE_hbase_regionserver_ipc_address` | `hbase.regionserver.ipc.address` | `0.0.0.0`     |
| `$HBASE_SITE_hbase_client_operation_timeout` | `hbase.client.operation.timeout` | `2000`        |
| `$HBASE_SITE_hbase_rpc_timeout`              | `hbase.rpc.timeout`              | `500`         |
| `$HBASE_SITE_hbase_client_retries_number`    | `hbase.client.retries.number`    | `2`           |
| `$HBASE_SITE_zookeeper_session_timeout`      | `zookeeper.session.timeout`      | `1000`        |
| `$HBASE_SITE_zookeeper_recovery_retry`       | `zookeeper.recovery.retry`       | `2`           |
| `$HBASE_SITE_hbase_client_pause`             | `hbase.client.pause`             | `100`         |

#### Non-default ports

You must change the environment variables corresponding to the advertised ports and addresses, and also
bind the same port both inside and outside the container:

```shell
$ docker run -d --rm --name hbase2-docker \
    --publish 18181:18181 \
    --publish 18000:18000 \
    --publish 18010:18010 \
    --publish 18020:18020 \
    --publish 18030:18030 \
    --env HBASE_SITE_hbase_zookeeper_property_clientPort=18181 \
    --env HBASE_SITE_hbase_zookeeper_quorum=localhost:18181 \
    --env HBASE_SITE_hbase_master_port=18000 \
    --env HBASE_SITE_hbase_master=localhost:18000 \
    --env HBASE_SITE_hbase_master_info_port=18010 \
    --env HBASE_SITE_hbase_regionserver_port=18020 \
    --env HBASE_SITE_hbase_regionserver_info_port=18030 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

If you won't bind the same port inside and outside the container, you also have to set `$HBASE_PORT_MAPPINGS` to
remap the container port to the advertised ports in the HBase configuration:

```shell
$ docker run -d --rm --name hbase2-docker \
    --publish 18181:2181 \
    --publish 18000:16000 \
    --publish 18010:16010 \
    --publish 18020:16020 \
    --publish 18030:16030 \
    --env HBASE_PORT_MAPPINGS='2181:18181 16000:18000 16010:18010 16020:18020 16030:18030' \
    --env HBASE_SITE_hbase_zookeeper_property_clientPort=18181 \
    --env HBASE_SITE_hbase_zookeeper_quorum=localhost:18181 \
    --env HBASE_SITE_hbase_master_port=18000 \
    --env HBASE_SITE_hbase_master=localhost:18000 \
    --env HBASE_SITE_hbase_master_info_port=18010 \
    --env HBASE_SITE_hbase_regionserver_port=18020 \
    --env HBASE_SITE_hbase_regionserver_info_port=18030 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

#### Non-default hostname

First of all, make sure the hostname you're gonna use is resolvable in the client machine. For instance, if you're using
a remote Docker instance, you'll need to use the hostname of the machine. In Docker Desktop, you'll probably need to use
`host.docker.internal` or `kubernetes.docker.internal`.

Then, you need to change the environment variables corresponding to the advertised hostnames and addresses, and also
add the custom host to the containers `/etc/hosts`:

```shell
$ docker run -d --rm --name hbase2-docker \
    --add-host machine.example.com=127.0.0.1 \
    --publish 2181:2181 \
    --publish 16000:16000 \
    --publish 16010:16010 \
    --publish 16020:16020 \
    --publish 16030:16030 \
    --env HBASE_SITE_hbase_zookeeper_quorum=machine.example.com:18181 \
    --env HBASE_SITE_hbase_master=machine.example.com:18000 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

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
