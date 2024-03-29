package io.github.diogenes1oliveira.hbase2;

import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.Get;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Table;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testcontainers.containers.output.Slf4jLogConsumer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;

@Testcontainers
public abstract class AbstractHBaseIT {
    @Container
    public HBaseContainer container = HBaseContainer.newBuilder().build();

    public Logger getLogger() {
        return LoggerFactory.getLogger(getClass());
    }

    @BeforeEach
    void setUp() {
        container.followOutput(new Slf4jLogConsumer(getLogger()));
    }

    @AfterEach
    void tearDown() {
        container.dropTables();
    }

    @Test
    void shouldBeAbleToCreateTablesViaHBaseApi() throws IOException {
        TableName tableName = TableName.valueOf("test-table-" + UUID.randomUUID());
        container.createTable(tableName, new byte[]{'f'});

        container.run(connection -> {
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

        });
    }

}
