package io.github.diogenes1oliveira.hbase2;

import com.github.dockerjava.api.DockerClient;

@FunctionalInterface
public interface DockerHostnameFunction {
    String getHostname(DockerClient dockerClient);

}
