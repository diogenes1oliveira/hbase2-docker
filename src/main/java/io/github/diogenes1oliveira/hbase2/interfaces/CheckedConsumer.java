package io.github.diogenes1oliveira.hbase2.interfaces;

/**
 * Functional interface alternative to Java's {@link java.util.function.Consumer} that can throw typed exceptions
 *
 * @param <T> the type of the input to the operation
 */
@FunctionalInterface
public interface CheckedConsumer<T> {
    void accept(T t) throws Exception;
}
