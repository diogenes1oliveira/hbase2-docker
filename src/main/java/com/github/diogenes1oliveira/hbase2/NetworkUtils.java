package com.github.diogenes1oliveira.hbase2;

import java.io.IOException;
import java.net.ServerSocket;
import java.util.Set;

public class NetworkUtils {
    private NetworkUtils() {
        // utility class
    }

    public static int getAvailablePort() {
        try {
            ServerSocket socket = new ServerSocket(0);
            socket.setReuseAddress(true);
            int port = socket.getLocalPort();
            socket.close();
            return port;
        } catch (IOException e) {
            throw new RuntimeException("No port available");
        }
    }

    public static int getAvailablePort(Set<Integer> excludedSet) {
        int port;
        do {
            port = getAvailablePort();
        } while (excludedSet.contains(port));

        return port;
    }

}
