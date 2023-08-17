package io.github.diogenes1oliveira.hbase2;

import io.github.diogenes1oliveira.hbase2.interfaces.CheckedBiConsumer;
import io.github.diogenes1oliveira.hbase2.interfaces.CheckedBiFunction;
import io.github.diogenes1oliveira.hbase2.interfaces.CheckedSupplier;
import org.apache.hadoop.hbase.client.Admin;
import org.apache.hadoop.hbase.client.Connection;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class HBaseContainerUtils {
    private static final Logger LOGGER = LoggerFactory.getLogger(HBaseContainerUtils.class);

    public static void uncheckedSleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            LOGGER.warn("interrupted while waiting", e);
            Thread.currentThread().interrupt();
            throw new RuntimeException("interrupted while waiting", e);
        }
    }

    @SuppressWarnings({"UnusedReturnValue"})
    public static void runWithRetry(Class<? extends Exception>[] ignoredExceptions,
                                    long timeoutNs,
                                    CheckedSupplier<Connection> connectionSupplier,
                                    CheckedBiConsumer<Connection, Admin> consumer) {
        getWithRetry(ignoredExceptions, null, timeoutNs, connectionSupplier, ((connection, admin) -> {
            consumer.accept(connection, admin);
            return null;
        }));
    }

    @SuppressWarnings({"UnusedReturnValue"})
    public static void runWithRetry(Class<? extends Exception> ignoredException,
                                    long timeoutNs,
                                    CheckedSupplier<Connection> connectionSupplier,
                                    CheckedBiConsumer<Connection, Admin> consumer) {
        Class<? extends Exception>[] ignoredExceptions = new Class[]{ignoredException};
        runWithRetry(ignoredExceptions, timeoutNs, connectionSupplier, consumer);
    }

    @SuppressWarnings({"UnusedReturnValue", "unchecked"})
    public static <T> T getWithRetry(Class<? extends Exception> ignoredException,
                                     T defaultValue,
                                     long timeoutNs,
                                     CheckedSupplier<Connection> connectionSupplier,
                                     CheckedBiFunction<Connection, Admin, T> function) {
        Class<? extends Exception>[] ignoredExceptions = new Class[]{ignoredException};
        return getWithRetry(ignoredExceptions, defaultValue, timeoutNs, connectionSupplier, function);
    }

    @SuppressWarnings({"UnusedReturnValue"})
    public static <T> T getWithRetry(Class<? extends Exception>[] ignoredExceptions,
                                     T defaultValue,
                                     long timeoutNs,
                                     CheckedSupplier<Connection> connectionSupplier,
                                     CheckedBiFunction<Connection, Admin, T> function) {
        long t0 = System.nanoTime();

        while (true) {
            try {
                try (Connection connection = connectionSupplier.get();
                     Admin admin = connection.getAdmin()) {
                    try {
                        return function.apply(connection, admin);
                    } catch (Exception e) {
                        for (Class<? extends Exception> ignoredException : ignoredExceptions) {
                            if (ignoredException.isAssignableFrom(e.getClass())) {
                                LOGGER.info("Caught ignored exception {}, returning default value {}", ignoredException.getName(), defaultValue);
                                return defaultValue;
                            }
                        }
                        throw e;
                    }
                }
            } catch (InterruptedException e) {
                LOGGER.warn("interrupted", e);
                Thread.currentThread().interrupt();
                throw new RuntimeException("interrupted", e);
            } catch (Exception e) {
                if (System.nanoTime() - t0 > timeoutNs) {
                    throw new RuntimeException("Timeout exceeded", e);
                }
                LOGGER.warn("failure, will retry again in 1s", e);
            }

            uncheckedSleep(1000);
        }
    }

}
