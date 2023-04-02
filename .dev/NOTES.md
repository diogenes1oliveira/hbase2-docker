### `start-hbase.sh`:

- sources hbase-config.sh
    - this one seems inconsequential. It does set `HBASE_CONF_DIR`, `HBASE_HOME`, sources `hbase-env.sh`...
- checks distMode=`$bin/hbase --config "$HBASE_CONF_DIR" org.apache.hadoop.hbase.util.HBaseConfTool hbase.cluster.distributed | head -n 1`
    - this means to check the configs for `hbase.cluster.distributed`
    - if !distMode, runs `hbase-daemon.sh --config "${HBASE_CONF_DIR}" start master`
    - if distMode, runs:
        * `hbase-daemon.sh --config "${HBASE_CONF_DIR}" start master` (same as !distMode)
        * Calls `hbase-daemons.sh` with `start regionserver`, `start master-backup`, `start zookeeper`
            - This just calls `zookeepers.sh`, `regionservers.sh`, `master-backup.sh` and SSHs into hosts
            - Ultimately it will run `hbase-daemon.sh start zookeeper,regionserver,master-backup` just like when distMode = false

So I can focus on getting `hbase-daemon.sh start $HBASE_ROLE` to execute properly inside Docker.

### `hbase-daemon.sh start $HBASE_ROLE`:

Initialization:

- sources hbase-config.sh
- sources hbase-common.sh
    - this one just defines `waitForProcessEnd()`
- then it sets some log and PID variables, some of which are forcibly set
    * **IMPORTANT** this might need some patching
    * `HBASE_LOGOUT`: seems to receive most logs
    * `HBASE_LOGGC`: interpolated in `SERVER_GC_OPTS` and `CLIENT_GC_OPTS` (JVM options)
      * This seems important to set. Maybe set a level to disable? Forward it to stdout?
    * `HBASE_LOGLOG`: seems to have just administrative stuff.
- sets `startStop=$1` (in our case `startStop=start`)
- sets `command=$2` (in our case `command=$HBASE_ROLE`)
- sets `thiscmd=bin/hbase-daemon.sh` to call itself again
- then it calls `foreground_start` redirecting the output to `HBASE_LOGOUT`


### `hbase-daemon.sh foreground_start $HBASE_ROLE`

It considers the variable `HBASE_NO_REDIRECT_LOG` to save to logs or not. Either way, starts this and waits for the PID to end:

```
        nice -n $HBASE_NICENESS "$HBASE_HOME"/bin/hbase \
            --config "${HBASE_CONF_DIR}" \
            $command "$@" start &
```

### `bin/hbase`

This also sets some variables before exec'ing into Java. Importantly, it sets this logging setting:

```
# Enable security logging on the master and regionserver only
if [ "$COMMAND" = "master" ] || [ "$COMMAND" = "regionserver" ]; then
  HBASE_OPTS="$HBASE_OPTS -Dhbase.security.logger=${HBASE_SECURITY_LOGGER:-INFO,RFAS}"
else
  HBASE_OPTS="$HBASE_OPTS -Dhbase.security.logger=${HBASE_SECURITY_LOGGER:-INFO,NullAppender}"
fi
```

So we should also set `HBASE_SECURITY_LOGGER=INFO,console`
