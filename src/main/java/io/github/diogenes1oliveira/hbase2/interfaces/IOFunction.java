package io.github.diogenes1oliveira.hbase2.interfaces;

import java.io.IOException;

/**
 * Functional interface alternative to Java's {@link java.util.function.Function} that can throw {@link IOException} exceptions
 *
 * @param <T> the type of the input to the function
 * @param <R> the type of the result of the function
 */
@FunctionalInterface
public interface IOFunction<T, R> {
    R apply(T t) throws IOException;
}
