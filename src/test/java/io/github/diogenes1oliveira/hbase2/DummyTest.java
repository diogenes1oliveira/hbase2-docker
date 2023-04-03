package io.github.diogenes1oliveira.hbase2;

import org.junit.jupiter.api.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;

public class DummyTest {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainerIT.class);

    @Test
    void mathShouldWork() {
        LOGGER.warn("running {}", DummyTest.class.getName());

        assertThat(2 + 2, equalTo(4));
    }
}
