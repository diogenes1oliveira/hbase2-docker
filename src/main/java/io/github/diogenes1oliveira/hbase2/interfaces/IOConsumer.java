package io.github.diogenes1oliveira.hbase2.interfaces;

import java.io.IOException;

/**
 * Functional interface alternative to Java's {@link java.util.function.Consumer} that can throw {@link IOException} exceptions
 *
 * @param <T> the type of the input to the operation
 */
@FunctionalInterface
public interface IOConsumer<T> {
    void accept(T t) throws IOException;
}
