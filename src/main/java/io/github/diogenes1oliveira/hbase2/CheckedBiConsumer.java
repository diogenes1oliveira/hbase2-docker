package io.github.diogenes1oliveira.hbase2;

/**
 * Function interface alternative to Java's {@link java.util.function.BiConsumer} that can throw typed exceptions
 *
 * @param <T> the type of the first argument to the operation
 * @param <U> the type of the second argument to the operation
 */
@FunctionalInterface
public interface CheckedBiConsumer<T, U> {
    void accept(T t, U u) throws Exception;
}
