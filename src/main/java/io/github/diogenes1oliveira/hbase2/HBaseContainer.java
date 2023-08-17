package io.github.diogenes1oliveira.hbase2;

import com.github.dockerjava.api.command.InspectContainerResponse;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.Admin;
import org.apache.hadoop.hbase.client.ColumnFamilyDescriptorBuilder;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;
import org.apache.hadoop.hbase.client.TableDescriptor;
import org.apache.hadoop.hbase.client.TableDescriptorBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.images.builder.Transferable;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

import static io.github.diogenes1oliveira.hbase2.PropertyUtils.envToProps;
import static io.github.diogenes1oliveira.hbase2.PropertyUtils.getProp;
import static io.github.diogenes1oliveira.hbase2.PropertyUtils.getProps;
import static io.github.diogenes1oliveira.hbase2.PropertyUtils.getResourceProps;
import static io.github.diogenes1oliveira.hbase2.PropertyUtils.mergeProps;
import static io.github.diogenes1oliveira.hbase2.PropertyUtils.propToEnv;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Arrays.stream;

/**
 * Testcontainer for HBase 2
 */
public class HBaseContainer extends GenericContainer<HBaseContainer> {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainer.class);

    public static final String ENV_DOTENV_NAME = "HBASE_ENV_FILE";
    public static final String ENV_DOTENV_VALUE = "/.env";
    public static final String ENV_PORT_ZOOKEEPER = "HBASE_SITE_hbase_zookeeper_property_clientPort";
    public static final String ENV_PORT_MASTER = "HBASE_SITE_hbase_master_port";
    public static final String ENV_HOSTNAME_MASTER = "HBASE_SITE_hbase_master_hostname";
    public static final String ENV_MASTER = "HBASE_SITE_hbase_master";
    public static final String ENV_QUORUM = "HBASE_SITE_hbase_zookeeper_quorum";
    public static final String ENV_HOSTNAME_REGIONSERVER = "HBASE_SITE_hbase_regionserver_hostname";
    public static final String ENV_PORT_MAPPINGS = "HBASE_PORT_MAPPINGS";

    public static final Map<String, Integer> DEFAULT_PORTS = new HashMap<String, Integer>() {{
        put(ENV_PORT_ZOOKEEPER, 2181);
        put(ENV_PORT_MASTER, 16000);
        put("HBASE_SITE_hbase_master_info_port", 16010);
        put("HBASE_SITE_hbase_regionserver_port", 16020);
        put("HBASE_SITE_hbase_regionserver_info_port", 16030);
    }};
    private final Map<String, String> env = new HashMap<>();
    private final Properties connectionProperties = new Properties();
    private final String hostname;
    private final long timeoutNs;
    private final boolean debug;

    /**
     * Name of the Docker image to be used
     */
    @SuppressWarnings({"resource"})
    public HBaseContainer(String image, Duration timeout, boolean debug, DockerHostnameFunction hostnameFunction, Properties defaultProps) {
        super(image);

        env.put(ENV_DOTENV_NAME, ENV_DOTENV_VALUE);
        withEnv(ENV_DOTENV_NAME, ENV_DOTENV_VALUE);

        this.hostname = hostnameFunction.getHostname(this.getDockerClient());
        if (!"localhost".equals(this.hostname)) {
            LOGGER.info("setting hostname {}=127.0.0.1", this.hostname);
            withExtraHost(hostname, "127.0.0.1");
        }

        this.timeoutNs = timeout.toNanos();
        for (String propName : defaultProps.stringPropertyNames()) {
            String envName = "HBASE_SITE_" + propToEnv(propName);
            withEnv(envName, defaultProps.getProperty(propName));
        }
        this.debug = debug;

        LOGGER.info("Starting container against image={} with timeout={} and debug={}", image, timeout, debug);
        if (debug) {
            LOGGER.info("Default properties: {}", defaultProps);
        }

        withStartupTimeout(timeout);
        withExposedPorts(DEFAULT_PORTS.values().toArray(new Integer[0]));
        waitingFor(Wait.forSuccessfulCommand("hbase2-docker-healthcheck"));
    }

    @Override
    protected void containerIsStarting(InspectContainerResponse containerInfo) {
        env.put(ENV_HOSTNAME_MASTER, hostname);
        env.put(ENV_HOSTNAME_REGIONSERVER, hostname);
        List<String> portMappings = new ArrayList<>();

        for (Map.Entry<String, Integer> entry : DEFAULT_PORTS.entrySet()) {
            String name = entry.getKey();
            int originalPort = entry.getValue();

            int mappedPort = getMappedPort(originalPort);

            env.put(name, Integer.toString(mappedPort));
            portMappings.add(originalPort + ":" + mappedPort);
        }

        env.put(ENV_PORT_MAPPINGS, String.join(", ", portMappings));
        env.put(ENV_MASTER, env.get(ENV_HOSTNAME_MASTER) + ":" + env.get(ENV_PORT_MASTER));
        env.put(ENV_QUORUM, env.get(ENV_HOSTNAME_MASTER) + ":" + env.get(ENV_PORT_ZOOKEEPER));

        String envContents = asEnvContents(env);
        if (debug) {
            LOGGER.info("Generated .env:\n{}", envContents);
        }
        byte[] envBytes = envContents.getBytes(UTF_8);

        LOGGER.info("copying .env to container");
        copyFileToContainer(Transferable.of(envBytes), ENV_DOTENV_VALUE);
        LOGGER.info(".env copied");
    }

    @Override
    protected void containerIsStarted(InspectContainerResponse containerInfo) {
        copyFileFromContainer("/etc/hbase/hbase-site.properties", stream -> {
            connectionProperties.load(stream);
            return null;
        });

        if (debug) {
            LOGGER.info("Final container properties: {}", connectionProperties);
        }
    }

    /**
     * Connection properties to connect to HBase within the container
     */
    public Properties getProperties() {
        return connectionProperties;
    }

    /**
     * Connection configuration to connect to HBase within the container
     */
    public Configuration getConfiguration() {
        Configuration conf = HBaseConfiguration.create();
        Properties props = getProperties();

        for (String name : props.stringPropertyNames()) {
            String value = props.getProperty(name);
            conf.set(name, value);
        }

        return conf;
    }

    public Connection getConnection() {
        try {
            return ConnectionFactory.createConnection(this.getConfiguration());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public void createTable(TableName tableName, byte[] family, byte[]... splits) {
        TableDescriptor descriptor = TableDescriptorBuilder.newBuilder(tableName)
                                                           .setColumnFamily(ColumnFamilyDescriptorBuilder.of(family))
                                                           .build();
        doWithRetry((_connection, admin) -> {
            if (splits.length != 0) {
                admin.createTable(descriptor, splits);
            } else {
                admin.createTable(descriptor);
            }
        });
    }

    public void createTable(String name, String family, String... splits) {
        byte[][] bytesSplits = stream(splits).map(s -> s.getBytes(UTF_8)).toArray(byte[][]::new);

        createTable(TableName.valueOf(name), family.getBytes(UTF_8), bytesSplits);
    }

    public void truncateTable(TableName tableName) {
        doWithRetry((_connection, admin) -> {
            if (admin.isTableEnabled(tableName)) {
                admin.disableTable(tableName);
            }
            admin.truncateTable(tableName, true);
            admin.enableTable(tableName);
        });
    }

    public void truncateTable(String name) {
        truncateTable(TableName.valueOf(name));
    }

    public void dropTable(TableName tableName) {
        doWithRetry((_connection, admin) -> {
            if (admin.isTableEnabled(tableName)) {
                admin.disableTable(tableName);
            }
            admin.deleteTable(tableName);
        });
    }

    public void dropTables() {
        doWithRetry((_connection, admin) -> {
            for (TableName tableName : admin.listTableNames()) {
                dropTable(tableName);
            }
        });
    }

    public static void uncheckedSleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            LOGGER.warn("interrupted while waiting", e);
            Thread.currentThread().interrupt();
            throw new RuntimeException("interrupted while waiting", e);
        }
    }

    @SuppressWarnings("UnusedReturnValue")
    public <T> T getWithRetry(CheckedBiFunction<Connection, Admin, T> function) {
        long t0 = System.nanoTime();

        while (true) {
            try {
                try (Connection connection = getConnection(); Admin admin = connection.getAdmin()) {
                    return function.apply(connection, admin);
                }
            } catch (InterruptedException e) {
                LOGGER.warn("interrupted", e);
                Thread.currentThread().interrupt();
                throw new RuntimeException("interrupted", e);
            } catch (Exception e) {
                if (System.nanoTime() - t0 > timeoutNs) {
                    throw new RuntimeException("Timeout exceeded", e);
                }
                LOGGER.warn("failure, will retry again in 1s", e);
            }

            uncheckedSleep(1000);
        }
    }

    public void doWithRetry(CheckedBiConsumer<Connection, Admin> consumer) {
        getWithRetry((connection, admin) -> {
            consumer.accept(connection, admin);
            return null;
        });
    }

    private static String asEnvContents(Map<String, String> env) {
        StringBuilder builder = new StringBuilder();

        for (Map.Entry<String, String> entry : env.entrySet()) {
            builder.append(entry.getKey());
            builder.append("=");
            builder.append(entry.getValue());
            builder.append("\n");
        }

        return builder.toString();
    }

    public static Builder newBuilder() {
        return new Builder();
    }

    public static Properties getHBase2DockerDefaultProps() {
        Properties props = getResourceProps("hbase2-docker.default.properties");
        props.putAll(getResourceProps("hbase2-docker.properties", false));

        return props;
    }

    @SuppressWarnings("resource")
    public static class Builder {
        private String image;
        private Duration timeout;
        private boolean debug;
        private boolean reuse;
        private Properties connectionProperties;
        private DockerHostnameFunction hostnameFunction;

        public Builder() {
            this(mergeProps(getHBase2DockerDefaultProps(), envToProps(System.getenv()), System.getProperties()));
        }

        public Builder(Properties props) {
            this.image = getProp(props, "hbase2-docker.image");
            this.timeout = getProp(props, "hbase2-docker.timeout", Duration::parse);
            this.debug = getProp(props, "hbase2-docker.debug", Boolean::parseBoolean);
            this.reuse = getProp(props, "hbase2-docker.reuse", Boolean::parseBoolean);
            this.connectionProperties = getProps(props, "hbase2-docker.connection.");

            String hostname = getProp(props, "hbase2-docker.hostname", false);
            String hostnameMapper = getProp(props, "hbase2-docker.hostname-mapper", false);

            if (hostname != null) {
                this.hostnameFunction = DockerHostnameFunctions.constant(hostname);
            } else if (hostnameMapper != null) {
                this.hostnameFunction = DockerHostnameFunctions.fromPropertySpec(hostnameMapper);
            } else {
                this.hostnameFunction = DockerHostnameFunctions.localhost();
            }
        }

        public Builder image(String image) {
            this.image = image;
            return this;
        }

        public Builder timeout(Duration timeout) {
            this.timeout = timeout;
            return this;
        }

        public Builder properties(Properties props) {
            this.connectionProperties = (Properties) props.clone();
            return this;
        }

        public Builder debug(boolean debug) {
            this.debug = debug;
            return this;
        }

        public Builder reuse(boolean reuse) {
            this.reuse = reuse;
            return this;
        }

        public Builder hostname(String hostname) {
            this.hostnameFunction = DockerHostnameFunctions.constant(hostname);
            return this;
        }

        public Builder hostname(DockerHostnameFunction hostnameFunction) {
            this.hostnameFunction = hostnameFunction;
            return this;
        }

        public HBaseContainer build() {
            return new HBaseContainer(image, timeout, debug, hostnameFunction, connectionProperties).withReuse(reuse);
        }
    }

}
