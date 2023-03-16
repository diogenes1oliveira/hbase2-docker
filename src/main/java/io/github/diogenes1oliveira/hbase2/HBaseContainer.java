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
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.AbstractWaitStrategy;
import org.testcontainers.containers.wait.strategy.WaitStrategy;
import org.testcontainers.utility.DockerImageName;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Arrays.stream;

/**
 * Testcontainer for HBase 2
 */
public class HBaseContainer extends GenericContainer<HBaseContainer> {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainer.class);

    public static final String DEFAULT_IMAGE = "diogenes1oliveira/hbase2-docker:1.0.0-hbase2.0.2";
    public static final String ZOOKEEPER_PORT_PROPERTY = "HBASE_CONF_hbase_zookeeper_property_clientPort";
    public static final Map<String, Integer> DEFAULT_PORTS = new HashMap<String, Integer>() {{
        put(ZOOKEEPER_PORT_PROPERTY, 2181);
        put("HBASE_CONF_hbase_master_port", 16000);
        put("HBASE_CONF_hbase_master_info_port", 16010);
        put("HBASE_CONF_hbase_regionserver_port", 16020);
        put("HBASE_CONF_hbase_regionserver_info_port", 16030);
    }};

    private final Properties properties;

    /**
     * Uses {@link #DEFAULT_IMAGE}
     */
    public HBaseContainer() {
        this(DEFAULT_IMAGE);
    }

    /**
     * Name of the Docker image to be used
     */
    public HBaseContainer(String image) {
        super(DockerImageName.parse(image));

        this.properties = new Properties() {
            {
                setProperty("hbase.client.operation.timeout", "10000");
                setProperty("hbase.rpc.timeout", "2000");
                setProperty("hbase.client.retries.number", "30");
                setProperty("zookeeper.session.timeout", "3000");
                setProperty("zookeeper.recovery.retry", "30");
                setProperty("hbase.client.pause", "500");
            }
        };

        Set<Integer> allocatedPorts = new HashSet<>();
        for (String name : DEFAULT_PORTS.keySet()) {
            int port = NetworkUtils.getAvailablePort(allocatedPorts);
            allocatedPorts.add(port);
            withEnv(name, Integer.toString(port));
            addFixedExposedPort(port, port);

            if (ZOOKEEPER_PORT_PROPERTY.equals(name)) {
                this.properties.setProperty("hbase.zookeeper.quorum", "localhost:" + port);
            }
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
        while (true) {
            try {
                try (Connection connection = getConnection();
                     Admin admin = connection.getAdmin()) {
                    if (admin.isTableEnabled(tableName)) {
                        admin.disableTable(tableName);
                    }
                    admin.deleteTable(tableName);
                }
                break;
            } catch (Exception e) {
                LOGGER.warn("failed to drop table " + tableName + ", trying again in 1 second", e);
                uncheckedSleep(1000);
            }
        }
    }

    public void dropTables() {
        while (true) {
            try {
                try (Connection connection = getConnection();
                     Admin admin = connection.getAdmin()) {
                    for (TableName tableName : admin.listTableNames()) {
                        dropTable(tableName);
                    }
                }
                break;
            } catch (Exception e) {
                LOGGER.info("failed to drop tables, trying again in 1 second", e);
                uncheckedSleep(1000);
            }
        }
    }

    public static void uncheckedSleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            LOGGER.warn("interrupted while sleeping", e);
            Thread.currentThread().interrupt();
            throw new RuntimeException("interrupted while sleeping", e);
        }
    }

    private WaitStrategy buildStatusWaitStrategy() {
        return new AbstractWaitStrategy() {
            @Override
            protected void waitUntilReady() {
                while (true) {
                    try {
                        if (execInContainer("/bin/hbase-shell-run.sh", "status").getExitCode() == 0) {
                            break;
                        }
                    } catch (IOException e) {
                        LOGGER.debug("Failed to create test table", e);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException(e);
                    }
                }
            }
        };
    }
}
