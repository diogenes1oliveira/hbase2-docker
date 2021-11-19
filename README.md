# hbase2-docker

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

This stack is mostly based on the repository https://github.com/big-data-europe/docker-hbase.

## Running

### Standalone mode

You can run a standalone HBase container directly via `docker run`:

```shell
$ docker run -it --rm \
    -p 2181:2181 -p 16000:16000 -p 16010:16010 -p 16020:16020 -p 16030:16030 \
    diogenes1oliveira/hbase2-docker:1.0.0-hbase2.0.2
```

Or you can use the convenience Makefile to start and follow the logs:

```shell
$ make run
$ make rm
```

The command above will start a standalone HBase cluster with all the necessary ports
bound to the local interface and with all hostnames bound and advertised to `localhost`.

To get more details about the standalone mode, check https://hbase.apache.org/book.html#standalone.

### Cluster Mode

You can run a full Hadoop and HBase cluster using the included [docker-compose.yml](docker-compose.yml).

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

## Development

The following build variables are available. Be sure to set them consistently when
executing multiple `make` commands:

| Variable         | Default                            | Description                  |
| ---------------- | ---------------------------------- | ---------------------------- |
| `IMAGE_BASENAME` | `diogenes1oliveira/hbase2-docker`  | Image basename               |
| `HBASE_VERSION`  | `2.0.2`                            | HBase version                |
| `VCS_REF`        | `1.0.0`                            | Git tag, commit ID or branch |
| `BUILD_VERSION`  | `${VCS_REF}-hbase${HBASE_VERSION}` | Image tag                    |
| `BUILD_DATE`     | `1970-01-01T00:00:00Z`             | Current UTC timestamp        |

Of course, you can also directly run `docker build` and `docker push`, but then you'll
have to set the build arguments directly. Check the aforementioned [Makefile](Makefile)
for more details.

### Building

Use the phony target `build` in the [Makefile](Makefile) to build the Docker
image:

```shell
$ make build VCS_REF=some-git-tag
```

### Linting

To run [hadolint](https://github.com/hadolint/hadolint) against the Dockerfile:

```shell
$ make lint
```

### Pushing

To push:

```shell
$ make push VCS_REF=some-git-tag
```
