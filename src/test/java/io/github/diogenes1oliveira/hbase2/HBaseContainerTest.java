package io.github.diogenes1oliveira.hbase2;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.containers.output.Slf4jLogConsumer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.UUID;

import static java.util.Collections.singletonList;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;

@Testcontainers
class HBaseContainerTest {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainerTest.class);

    @Container
    public HBaseContainer container = new HBaseContainer();

    @BeforeEach
    void setUp() {
        container.followOutput(new Slf4jLogConsumer(LOGGER));
    }

    @Test
    void shouldBeAbleToCreateTablesViaHBaseApi() throws IOException {
        ColumnFamilyDescriptor familyDescriptor = ColumnFamilyDescriptorBuilder.of("f");
        TableName tableName = TableName.valueOf("test-table-" + UUID.randomUUID());
        TableDescriptor tableDescriptor = TableDescriptorBuilder.newBuilder(tableName)
                .setColumnFamilies(singletonList(familyDescriptor))
                .build();

        Configuration config = createConfig(container.getProperties());

        try (Connection connection = ConnectionFactory.createConnection(config); Admin admin = connection.getAdmin()) {
            admin.createTable(tableDescriptor);
            testTablePutAndGet(connection, tableName);
            admin.disableTable(tableName);
            admin.deleteTable(tableName);
        }
    }

    private void testTablePutAndGet(Connection connection, TableName tableName) throws IOException {
        byte[] row = ("row-" + UUID.randomUUID()).getBytes(StandardCharsets.UTF_8);
        byte[] family = "f".getBytes(StandardCharsets.UTF_8);
        byte[] col = "col".getBytes(StandardCharsets.UTF_8);
        String putValue = "put-" + UUID.randomUUID();

        Put put = new Put(row);
        put.addColumn(family, col, putValue.getBytes(StandardCharsets.UTF_8));

        Get get = new Get(row);
        get.addColumn(family, col);

        try (Table table = connection.getTable(tableName)) {
            table.put(put);
        }

        try (Table table = connection.getTable(tableName)) {
            String getValue = new String(table.get(get).getValue(family, col), StandardCharsets.UTF_8);
            assertThat(getValue, equalTo(putValue));
        }

    }

    private static Configuration createConfig(Properties props) {
        Configuration config = new Configuration();

        for (String name : props.stringPropertyNames()) {
            String value = props.getProperty(name);
            config.set(name, value);
        }

        return config;
    }
}
