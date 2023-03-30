package io.github.diogenes1oliveira.hbase2;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.ServerSocket;
import java.util.Set;

public final class NetworkUtils {
    private NetworkUtils() {
        // utility class
    }

    public static int getAvailablePort() {
        try (ServerSocket socket = new ServerSocket(0)) {
            socket.setReuseAddress(true);
            return socket.getLocalPort();
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to get free port", e);
        }
    }

    public static int allocateAnotherPort(Set<Integer> allocatedPorts) {
        int port;
        do {
            port = getAvailablePort();
        } while (allocatedPorts.contains(port));

        allocatedPorts.add(port);
        return port;
    }

}
