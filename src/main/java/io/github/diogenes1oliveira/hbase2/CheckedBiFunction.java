package io.github.diogenes1oliveira.hbase2;

/**
 * Function interface alternative to Java's {@link java.util.function.BiFunction} that can throw typed exceptions
 *
 * @param <T> the type of the first argument to the function
 * @param <U> the type of the second argument to the function
 * @param <R> the type of the result of the function
 */
@FunctionalInterface
public interface CheckedBiFunction<T, U, R> {
    R apply(T t, U u) throws Exception;
}
