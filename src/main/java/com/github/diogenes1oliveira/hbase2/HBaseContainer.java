package com.github.diogenes1oliveira.hbase2;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.AbstractWaitStrategy;
import org.testcontainers.containers.wait.strategy.WaitStrategy;
import org.testcontainers.utility.DockerImageName;

import java.io.IOException;
import java.util.*;

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

    public HBaseContainer() {
        this(DEFAULT_IMAGE);
    }

    public HBaseContainer(String image) {
        super(DockerImageName.parse(image));

        this.properties = new Properties() {{
            setProperty("hbase.client.operation.timeout", "10000");
            setProperty("hbase.rpc.timeout", "2000");
            setProperty("hbase.client.retries.number", "30");
            setProperty("zookeeper.session.timeout", "3000");
            setProperty("zookeeper.recovery.retry", "30");
            setProperty("hbase.client.pause", "500");
        }};

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

    public Properties getProperties() {
        return properties;
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
