#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$0"

usage() {
    cat <<eof
Builds the XML settings from environment variables with prefix HBASE_CONF

Usage:
    ${SCRIPT} [ -q | --quiet ] [ -n | --no-defaults ] [ TYPE ]

Options:
    -n, --no-defaults  don't set default values for the environment variables
    -q, --quiet        don't log configurations 
    TYPE               xml | properties | eval | env (default: 'xml')

Environment variables:
    \$HBASE_CONF_DIR    path to HBase configuration directory
                       (default: /etc/hbase)
    \$HBASE_ENV_FILE    path to an optional .env file to be sourced before
                        building the configuration. Only single-lined values
                        are supported
    \$HBASE_ROLE        master | regionserver | standalone (default: standalone)
    \$JAVA_HOME         path to a Java installation (default: /usr)

This script maps environment variables with the prefix HBASE_CONF_ by removing
the prefix and replacing dots by underscores:

<!-- HBASE_CONF_some_config=value -->
<property>
    <name>some.config</name>
    <value>value</value>
</property>
eof
}

main() {
    args_parse "$@"

    if [ -n "${HBASE_ENV_FILE:-}" ]; then
        hbase_dotenv_load "${HBASE_ENV_FILE}"
    fi

    if [ "${NO_DEFAULTS}" != 'true' ]; then
        hbase_set_default_envs
    fi

    case "${TYPE}" in
    xml | properties )
        configure "${HBASE_CONF_DIR}/hbase-site.xml" hbase HBASE_CONF ;;
    eval )
        hbase_print_env ;;
    esac
}

hbase_dotenv_load() {
    dotenv_file="$1"
    dotenv_script="$(
        cd "$(realpath "$(dirname "${SCRIPT}")")"
        realpath 'dotenv-load.sh'
    )"
    # shellcheck disable=SC1090
    source "${dotenv_script}" "${dotenv_file}"
}

hbase_set_default_envs() {
    export HBASE_CONF_hbase_rootdir="${HBASE_CONF_hbase_rootdir:-/var/lib/hbase}"

    export HBASE_CONF_hbase_master_ipc_address="${HBASE_CONF_hbase_master_ipc_address:-0.0.0.0}"
    export HBASE_CONF_hbase_master_hostname="${HBASE_CONF_hbase_master_hostname:-localhost}"
    export HBASE_CONF_hbase_master_port="${HBASE_CONF_hbase_master_port:-16000}"
    export HBASE_CONF_hbase_master_info_port="${HBASE_CONF_hbase_master_info_port:-16010}"
    export HBASE_CONF_hbase_master="${HBASE_CONF_hbase_master:-${HBASE_CONF_hbase_master_hostname}:${HBASE_CONF_hbase_master_port}}"

    export HBASE_CONF_hbase_zookeeper_property_clientPort="${HBASE_CONF_hbase_zookeeper_property_clientPort:-2181}"
    export HBASE_CONF_hbase_zookeeper_peerport="${HBASE_CONF_hbase_zookeeper_peerport:-2888}"
    export HBASE_CONF_hbase_zookeeper_leaderport="${HBASE_CONF_hbase_zookeeper_leaderport:-3888}"
    export HBASE_CONF_hbase_zookeeper_quorum="${HBASE_CONF_hbase_zookeeper_quorum:-${HBASE_CONF_hbase_master_hostname}:${HBASE_CONF_hbase_zookeeper_property_clientPort}}"

    if [ "${HBASE_ROLE}" = 'standalone' ]; then
        info 'Setting up default standalone settings'
        export HBASE_CONF_hbase_cluster_distributed="${HBASE_CONF_hbase_cluster_distributed:-false}"
        export HBASE_CONF_hbase_unsafe_stream_capability_enforce="${HBASE_CONF_hbase_unsafe_stream_capability_enforce:-false}"
        export HBASE_MANAGES_ZK="${HBASE_MANAGES_ZK:-true}"
        export HBASE_CONF_hbase_zookeeper_property_dataDir="${HBASE_CONF_hbase_zookeeper_property_dataDir:-/var/lib/zookeeper}"
    else
        info 'Setting up default cluster settings'
        export HBASE_CONF_hbase_cluster_distributed="${HBASE_CONF_hbase_cluster_distributed:-true}"
        export HBASE_CONF_hbase_unsafe_stream_capability_enforce="${HBASE_CONF_hbase_unsafe_stream_capability_enforce:-true}"
        export HBASE_MANAGES_ZK="${HBASE_MANAGES_ZK:-false}"
    fi

    if [ "${HBASE_ROLE}" != 'master' ]; then
        info 'Setting up default region server settings'
        export HBASE_CONF_hbase_regionserver_ipc_address="${HBASE_CONF_hbase_regionserver_ipc_address:-0.0.0.0}"
        export HBASE_CONF_hbase_regionserver_hostname="${HBASE_CONF_hbase_regionserver_hostname:-localhost}"
        export HBASE_CONF_hbase_regionserver_port="${HBASE_CONF_hbase_regionserver_port:-16020}"
        export HBASE_CONF_hbase_regionserver_info_port="${HBASE_CONF_hbase_regionserver_info_port:-16030}"
    fi

}

add_property() {
    local path="$1"
    local name="$2"
    local value="$3"

    entry="<property><name>${name}</name><value>${value}</value></property>"
    escaped_entry="$(echo "${entry}" | sed 's/\//\\\//g')"
    if ! [ -f "${path}.bkp" ]; then
        cp "${path}" "${path}.bkp"
    fi
    sed -i "/<\/configuration>/ s/.*/${escaped_entry}\n&/" "${path}"
}

hbase_print_env() (
    cd "$(dirname "$(realpath "${SCRIPT}")")"

    while read -r name; do
        if [[ "${name}" = HBASE_* ]]; then
            printf 'export %s=%s\n' "${name}" "$(./shell-pprint.sh <<<"${!name}")"
        fi
    done < <( awk 'BEGIN{for(v in ENVIRON) print v}' )
)

configure() {
    local path="$1"
    local module="$2"
    local env_prefix="$3"

    local var
    local value

    info "Configuring ${module}"
    for c in $(printenv | grep -v '^HBASE_CONF_DIR' | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- "-envPrefix=${env_prefix}"); do
        name="$(printf '%s' "${c}" | perl -pe 's/___/-/g; s/__/_/g; s/_/./g')"
        var="${env_prefix}_${c}"
        value="${!var}"
        info "  Setting ${name}=${value}"

        case "${TYPE}" in
        xml )
            add_property "${HBASE_CONF_DIR}/${module}-site.xml" "${name}" "${value}" ;;
        properties )
            printf '%s\n' "${name}=${value}" ;;
        esac
    done
}

args_error() {
    msg="$1"

    usage >&2
    echo >&2
    echo >&2 "ERROR: ${msg}"
    return 1
}

args_parse() {
    export HBASE_CONF_DIR="${HBASE_CONF_DIR:-/etc/hbase}"
    export HBASE_ROLE="${HBASE_ROLE:-standalone}"
    export JAVA_HOME="${JAVA_HOME:-/usr}"

    if ! [[ "${HBASE_ROLE}" =~ ^(standalone|master|regionserver)$ ]]; then
        args_error "invalid role ${HBASE_ROLE}"
    fi

    if ! OPTS="$(getopt -l 'help,no-defaults,quiet' -o 'hnq' -- "$@")"; then
        args_error 'failed to parse args'
    fi

    eval set -- "${OPTS}"

    for arg in "$@"; do
        case "${arg}" in
        -h | --help )
            usage && exit 0 ;;
        -n | --no-defaults )
            NO_DEFAULTS=true && shift ;;
        -q | --quiet )
            QUIET=true && shift ;;
        -- )
            shift && break ;;
        * )
            args_error "Unknown argument ${arg}" ;;
        esac
    done

    TYPE="${1:-xml}"
    QUIET="${QUIET:-false}"
    NO_DEFAULTS="${NO_DEFAULTS:-false}"

    if ! [[ "${TYPE}" =~ ^(xml|properties|eval|env)$ ]]; then
        args_error "invalid config type ${TYPE}"
    fi
}

info() {
    if [ "${QUIET}" != 'true' ]; then
        echo >&2 "CONFIG: $*"
    fi
}

main "$@"
