package io.github.diogenes1oliveira.hbase2;

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
import org.testcontainers.containers.FixedHostPortGenericContainer;
import org.testcontainers.containers.wait.strategy.AbstractWaitStrategy;
import org.testcontainers.containers.wait.strategy.WaitStrategy;
import org.testcontainers.images.builder.Transferable;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Duration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.function.Function;

import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Arrays.stream;

/**
 * Testcontainer for HBase 2
 */
public class HBaseContainer extends FixedHostPortGenericContainer<HBaseContainer> {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainer.class);

    public static final String ENV_DOTENV_NAME = "HBASE_ENV_FILE";
    public static final String ENV_DOTENV_VALUE = "/.env";
    public static final String ENV_PORT_ZOOKEEPER = "HBASE_CONF_hbase_zookeeper_property_clientPort";
    public static final String ENV_HOSTNAME_MASTER = "HBASE_CONF_hbase_master_hostname";
    public static final String ENV_HOSTNAME_REGIONSERVER = "HBASE_CONF_hbase_regionserver_hostname";
    public static final String RESOURCE_CONFIG = "hbase2-docker.properties";
    public static final String PROP_DEFAULT_IMAGE = "hbase2-docker.default-image";
    public static final String PROPS_DEFAULT_TIMEOUT = "hbase2-docker.default-timeout";

    public static final Function<HBaseContainer, String> HOST_IP_FUNCTION = HBaseContainer::getContainerIpAddress;
    public static final Function<HBaseContainer, String> CONTAINER_IP_FUNCTION = container ->
            container.getCurrentContainerInfo().getNetworkSettings().getIpAddress();
    public static final Map<String, Integer> DEFAULT_PORTS = new HashMap<String, Integer>() {{
        put(ENV_PORT_ZOOKEEPER, 2181);
        put("HBASE_CONF_hbase_master_port", 16000);
        put("HBASE_CONF_hbase_master_info_port", 16010);
        put("HBASE_CONF_hbase_regionserver_port", 16020);
        put("HBASE_CONF_hbase_regionserver_info_port", 16030);
    }};
    public static final Set<Integer> DEFAULT_PORT_NUMBERS = new HashSet<>(DEFAULT_PORTS.values());
    private final Properties properties;
    private final Function<HBaseContainer, String> getIpFunction;
    private final Map<String, String> env = new HashMap<>();
    private final long timeoutNs;

    /**
     * Name of the Docker image to be used
     */
    @SuppressWarnings({"resource", "deprecation"})
    public HBaseContainer(String image, Function<HBaseContainer, String> getIpFunction, Duration timeout, Properties props) {
        super(image);

        withEnv(ENV_DOTENV_NAME, ENV_DOTENV_VALUE);

        this.getIpFunction = getIpFunction;
        this.timeoutNs = timeout.toNanos();
        this.properties = props;

        Set<Integer> ports = new HashSet<>(DEFAULT_PORT_NUMBERS);

        for (String name : DEFAULT_PORTS.keySet()) {
            int port = NetworkUtils.allocateAnotherPort(ports);

            addFixedExposedPort(port, port);
            env.put(name, Integer.toString(port));
        }

        waitingFor(buildStatusWaitStrategy());
    }

    /**
     * Connection properties to connect to HBase within the container
     */
    public Properties getProperties() {
        return properties;
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
        while (true) {
            try {
                try (Connection connection = getConnection();
                     Admin admin = connection.getAdmin()) {
                    if (splits.length != 0) {
                        admin.createTable(descriptor, splits);
                    } else {
                        admin.createTable(descriptor);
                    }
                }
                break;
            } catch (Exception e) {
                LOGGER.info("failed to create table, trying again in 1 second", e);
                uncheckedSleep(1000);
            }
        }
    }

    public void createTable(String name, String family, String... splits) {
        byte[][] bytesSplits = stream(splits).map(s -> s.getBytes(UTF_8)).toArray(byte[][]::new);

        createTable(TableName.valueOf(name), family.getBytes(UTF_8), bytesSplits);
    }

    public void truncateTable(TableName tableName) {
        while (true) {
            try {
                try (Connection connection = getConnection();
                     Admin admin = connection.getAdmin()) {
                    if (admin.isTableEnabled(tableName)) {
                        admin.disableTable(tableName);
                    }
                    admin.truncateTable(tableName, true);
                    admin.enableTable(tableName);
                }
                break;
            } catch (Exception e) {
                LOGGER.warn("failed to drop table " + tableName + ", trying again in 1 second", e);
                uncheckedSleep(1000);
            }
        }
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

    private void setupContainer() {
        String containerIp = getIpFunction.apply(this);

        properties.setProperty("hbase.zookeeper.quorum", containerIp + ":" + env.get(ENV_PORT_ZOOKEEPER));
        env.put(ENV_HOSTNAME_MASTER, containerIp);
        env.put(ENV_HOSTNAME_REGIONSERVER, containerIp);

        String envContents = asEnvContents(env);
        byte[] envBytes = envContents.getBytes(UTF_8);

        copyFileToContainer(Transferable.of(envBytes), ENV_DOTENV_VALUE);
    }

    private WaitStrategy buildStatusWaitStrategy() {

        return new AbstractWaitStrategy() {
            @Override
            protected void waitUntilReady() {
                setupContainer();

                while (true) {
                    try {
                        if (execInContainer("/bin/hbase-shell-run.sh", "status").getExitCode() == 0) {
                            break;
                        }
                        LOGGER.warn("failed to run 'status' command via hbase shell, trying again in 10s");
                        Thread.sleep(10_000);
                    } catch (IOException e) {
                        LOGGER.error("Failed to check HBase status", e);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException(e);
                    }
                }
            }

        };
    }

    public static Builder newBuilder() {
        return new Builder();
    }

    public static Properties getDefaultProps() {
        try (InputStream stream = HBaseContainer.class.getClassLoader().getResourceAsStream(RESOURCE_CONFIG)) {
            if (stream == null) {
                throw new IOException("No such resource: " + RESOURCE_CONFIG);
            }
            Properties props = new Properties();
            props.load(stream);

            return props;
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public static class Builder {
        private String image;
        private Function<HBaseContainer, String> ipFunction = HOST_IP_FUNCTION;
        private Duration timeout;
        private Properties props;

        public Builder() {
            this.props = getDefaultProps();
            this.image = (String) this.props.remove(PROP_DEFAULT_IMAGE);
            this.timeout = Duration.parse((String) this.props.remove(PROPS_DEFAULT_TIMEOUT));
        }

        public Builder image(String image) {
            this.image = image;
            return this;
        }

        public Builder ipFunction(Function<HBaseContainer, String> ipFunction) {
            this.ipFunction = ipFunction;
            return this;
        }

        public Builder timeout(Duration timeout) {
            this.timeout = timeout;
            return this;
        }

        public Builder properties(Properties props) {
            this.props = (Properties) props.clone();
            return this;
        }

        public HBaseContainer build() {
            return new HBaseContainer(image, ipFunction, timeout, props);
        }
    }

}
