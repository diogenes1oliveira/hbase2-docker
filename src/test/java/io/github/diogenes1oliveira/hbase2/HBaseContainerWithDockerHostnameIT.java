package io.github.diogenes1oliveira.hbase2;

import org.junit.jupiter.api.Test;
import org.junitpioneer.jupiter.ClearSystemProperty;
import org.junitpioneer.jupiter.SetSystemProperty;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.not;

@ClearSystemProperty(key = "hbase2-docker.hostname")
@SetSystemProperty(key = "hbase2-docker.hostname-mapper", value = "io.github.diogenes1oliveira.hbase2.DockerHostnameFunctions#dockerHostname")
class HBaseContainerWithDockerHostnameIT extends AbstractHBaseIT {
    @Test
    void shouldNotBeLocalhost() {
        String quorum = container.getProperties().getProperty("hbase.zookeeper.quorum");
        assertThat(quorum.split(":")[0], not(equalTo("localhost")));
    }

}
