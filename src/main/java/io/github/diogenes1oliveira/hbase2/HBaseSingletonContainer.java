package io.github.diogenes1oliveira.hbase2;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.containers.output.Slf4jLogConsumer;

public class HBaseSingletonContainer {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseSingletonContainer.class);
    private static HBaseContainer container = null;

    public static synchronized HBaseContainer instance() {
        if (container == null) {
            container = HBaseContainer.newBuilder().build();
            container.start();
            container.followOutput(new Slf4jLogConsumer(LOGGER));
        }

        return container;
    }
}
