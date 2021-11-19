#!/usr/bin/env bash

hbase_master="${HBASE_CONF_hbase_master_hostname:-}:${HBASE_CONF_hbase_master_port:-}"
if [[ "${hbase_master}" =~ .+:.+ && -z "${HBASE_CONF_hbase_master:-}" ]]; then
    export HBASE_CONF_hbase_master="${hbase_master}"
fi

zookeeper_quorum="${HBASE_CONF_hbase_master_hostname:-}:${HBASE_CONF_hbase_zookeeper_property_clientPort:-}"
if [[ "${zookeeper_quorum}" =~ .+:.+ && -z "${HBASE_CONF_hbase_zookeeper_quorum:-}" ]]; then
    export HBASE_CONF_hbase_zookeeper_quorum="${zookeeper_quorum}"
fi

function info() {
    echo >&2 "INFO: $@"
}

function addProperty() {
    local path=$1
    local name=$2
    local value=$3

    local entry="<property><name>$name</name><value>${value}</value></property>"
    local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
    sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function configure() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value

    info "Configuring $module"
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/_/g; s/_/./g'`
        var="${envPrefix}_${c}"
        value=${!var}
        info "  Setting $name=$value"
        addProperty /etc/hbase/$module-site.xml $name "$value"
    done
}

configure /etc/hbase/hbase-site.xml hbase HBASE_CONF

function wait_for_it()
{
    local serviceport=$1
    local service=${serviceport%%:*}
    local port=${serviceport#*:}
    local retry_seconds=5
    local max_try=100
    let i=1

    nc -z $service $port
    result=$?

    until [ $result -eq 0 ]; do
        info "[$i/$max_try] check for ${service}:${port}..."
        info "[$i/$max_try] ${service}:${port} is not available yet"
        if (( $i == $max_try )); then
            info "[$i/$max_try] ${service}:${port} is still not available; giving up after ${max_try} tries. :/"
            exit 1
        fi

        info "[$i/$max_try] try in ${retry_seconds}s once again ..."
        let "i++"
        sleep $retry_seconds

        nc -z $service $port
        result=$?
    done
    info "[$i/$max_try] $service:${port} is available."
}

for i in "${SERVICE_PRECONDITION[@]}"
do
    wait_for_it ${i}
done


if [ "$#" -eq 0 ] || [ "${1#-}" != "${1}" ]; then
    # no args or first arg is a flag
    exec /bin/hbase-start-and-follow.sh "$@"
else
    exec "$@"
fi
