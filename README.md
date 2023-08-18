# [hbase2-docker](https://github.com/diogenes1oliveira/hbase2-docker)

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
    -p 2181:2181 -p 16000:16000 -p 16010:16010 -p 16020:16020 -p 16030:16030 -p 17000:17000 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

You can also use the [docker-compose.yml](./docker-compose.yml) included in this repo:

```shell
$ docker compose up || docker-compose up
```

The commands above will start a standalone HBase cluster with all the necessary ports
bound to the local interface and with all hostnames advertised to `localhost`. The Master Web UI is accessible at
http://localhost:16010/ and a custom health check page is available at http://localhost:17000/.

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
| `$HBASE_HEALTHCHECK_PORT`            | `17000`                                                | port to bind the healthcheck server to                                                                                                                                                                                                |
| `$HBASE_POST_INITIALIZATION_COMMAND` | -                                                      | file or string with hbase shell commands to run after the healthcheck succeeds for the first time                                                                                                                                     |

#### HBase configurations

The [hadoop-config-from-env](./bin/hadoop-config-from-env) script maps environment variables with the prefix
`HBASE_SITE_` by removing the prefix and replacing underscores by dots or dashes. The resulting configurations are saved to `/etc/hbase/hbase-site.xml`
and `/etc/hbase/hbase-site.properties`:

```shell
$ export HBASE_SITE_CONFIG_WITH_DOTS=value
$ export HBASE_SITE_CONFIG__WITH__DASHES=value
$ export HBASE_SITE_TRIPLE___UNDERSCORE____ESCAPES=value
```

```xml
<!-- hbase-site.xml -->
<property>
    <name>config.with.dots</name>
    <value>value</value>
</property>
<property>
    <name>config-with-dashes</name>
    <value>value</value>
</property>
<property>
    <name>tripleUnderscore_escapes</name>
    <value>value</value>
</property>
```

```properties
# hbase-site.properties
config.with.dots=value
config-with-dashes=value
tripleUnderscore_escapes=value
```

Core configurations:

| Environment variable name                            | HBase configuration                      | Default value        | Description                                                          |
| ---------------------------------------------------- | ---------------------------------------- | -------------------- | -------------------------------------------------------------------- |
| `$HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_DATA___DIR`    | `hbase.zookeeper.property.dataDir`       | `/var/lib/zookeeper` | path to store the zookeeper data                                     |
| `$HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT` | `hbase.zookeeper.property.clientPort`    | `2181`               | port the embedded zookeeper should bind to                           |
| `$HBASE_SITE_HBASE_ROOTDIR`                          | `hbase.rootdir`                          | `/var/lib/hbase`     | path to store the HBase data                                         |
| `$HBASE_SITE_HBASE_CLUSTER_DISTRIBUTED`              | `hbase.cluster.distributed`              | `false`              | whether to run in standalone mode (`false`) or cluster mode (`true`) |
| `$HBASE_SITE_HBASE_UNSAFE_STREAM_CAPABILITY_ENFORCE` | `hbase.unsafe.stream.capability.enforce` | `false`              | set to false if the HBase data is stored in the local filesystem     |
| `$HBASE_SITE_HBASE_MASTER_HOSTNAME`                  | `hbase.master.hostname`                  | `localhost`          | advertised hostname for the master node                              |
| `$HBASE_SITE_HBASE_MASTER_PORT`                      | `hbase.master.port`                      | `16000`              | advertised port for the master node                                  |
| `$HBASE_SITE_HBASE_MASTER`                           | `hbase.master`                           | `localhost:16000`    | advertised address for the master node                               |
| `$HBASE_SITE_HBASE_MASTER_INFO_PORT`                 | `hbase.master.info.port`                 | `16010`              | port for the master UI interface                                     |
| `$HBASE_SITE_HBASE_REGIONSERVER_HOSTNAME`            | `hbase.regionserver.hostname`            | `localhost`          | advertised hostname for the region server node                       |
| `$HBASE_SITE_HBASE_REGIONSERVER_PORT`                | `hbase.regionserver.port`                | `16020`              | advertised port for the region server node                           |
| `$HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT`           | `hbase.regionserver.info.port`           | `16030`              | port for the region server UI interface                              |
| `$HBASE_SITE_HBASE_ZOOKEEPER_QUORUM`                 | `hbase.zookeeper.quorum`                 | `localhost:2181`     | comma-separated addresses of the zookeeper cluster                   |

Extra configurations:

| Environment variable name                    | HBase configuration              | Default value |
| -------------------------------------------- | -------------------------------- | ------------- |
| `$HBASE_SITE_HBASE_MASTER_IPC_ADDRESS`       | `hbase.master.ipc.address`       | `0.0.0.0`     |
| `$HBASE_SITE_HBASE_REGIONSERVER_IPC_ADDRESS` | `hbase.regionserver.ipc.address` | `0.0.0.0`     |
| `$HBASE_SITE_HBASE_CLIENT_OPERATION_TIMEOUT` | `hbase.client.operation.timeout` | `2000`        |
| `$HBASE_SITE_HBASE_RPC_TIMEOUT`              | `hbase.rpc.timeout`              | `500`         |
| `$HBASE_SITE_HBASE_CLIENT_RETRIES_NUMBER`    | `hbase.client.retries.number`    | `2`           |
| `$HBASE_SITE_ZOOKEEPER_SESSION_TIMEOUT`      | `zookeeper.session.timeout`      | `1000`        |
| `$HBASE_SITE_ZOOKEEPER_RECOVERY_RETRY`       | `zookeeper.recovery.retry`       | `2`           |
| `$HBASE_SITE_HBASE_CLIENT_PAUSE`             | `hbase.client.pause`             | `100`         |

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
    --publish 19000:19000 \
    --env HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT=18181 \
    --env HBASE_SITE_HBASE_ZOOKEEPER_QUORUM=localhost:18181 \
    --env HBASE_SITE_HBASE_MASTER_PORT=18000 \
    --env HBASE_SITE_HBASE_MASTER=localhost:18000 \
    --env HBASE_SITE_HBASE_MASTER_INFO_PORT=18010 \
    --env HBASE_SITE_HBASE_REGIONSERVER_PORT=18020 \
    --env HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT=18030 \
    --env HBASE_HEALTHCHECK_PORT=19000 \
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
    --publish 19000:17000 \
    --env HBASE_PORT_MAPPINGS='2181:18181 16000:18000 16010:18010 16020:18020 16030:18030 17000:19000' \
    --env HBASE_SITE_HBASE_ZOOKEEPER_PROPERTY_CLIENT___PORT=18181 \
    --env HBASE_SITE_HBASE_ZOOKEEPER_QUORUM=localhost:18181 \
    --env HBASE_SITE_HBASE_MASTER_PORT=18000 \
    --env HBASE_SITE_HBASE_MASTER=localhost:18000 \
    --env HBASE_SITE_HBASE_MASTER_INFO_PORT=18010 \
    --env HBASE_SITE_HBASE_REGIONSERVER_PORT=18020 \
    --env HBASE_SITE_HBASE_REGIONSERVER_INFO_PORT=18030 \
    --env HBASE_HEALTHCHECK_PORT=19000 \
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
    --publish 17000:17000 \
    --env HBASE_SITE_HBASE_ZOOKEEPER_QUORUM=machine.example.com:2181 \
    --env HBASE_SITE_HBASE_MASTER=machine.example.com:16000 \
    diogenes1oliveira/hbase2-docker:0.2.0-hbase2.0.2
```

### Testcontainers

The [Testcontainers](https://testcontainers.com/) `io.github.diogenes1oliveira:hbase2-testcontainers` dependency is published to
[Maven central](https://mvnrepository.com/artifact/io.github.diogenes1oliveira/hbase2-testcontainers) to aid using this container
in Java integration tests:

```xml
<!-- https://mvnrepository.com/artifact/io.github.diogenes1oliveira/hbase2-testcontainers -->
<dependency>
    <groupId>io.github.diogenes1oliveira</groupId>
    <artifactId>hbase2-testcontainers</artifactId>
    <version>0.2.0</version>
</dependency>
```

Then you can use it in your integration tests as such:

```java

import io.github.diogenes1oliveira.hbase2.HBaseContainer;
import java.util.Properties;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers
public class HBaseTest {
    @Container
    public HBaseContainer container = HBaseContainer.newBuilder().build();

    @Test
    void shouldConnect() {
        // Java properties
        Properties props = container.getProps();

        // Hadoop configuration object
        Configuration conf = container.getConfiguration();
        Connection connection = ConnectionFactory.createConnection(conf);
    }

}

```
