package io.github.diogenes1oliveira.hbase2.interfaces;

/**
 * Functional interface alternative to Java's {@link java.util.function.Supplier} that can throw typed exceptions
 *
 * @param <T> the type of results supplied by this supplier
 */
@FunctionalInterface
public interface CheckedSupplier<T> {
    T get() throws Exception;
}
