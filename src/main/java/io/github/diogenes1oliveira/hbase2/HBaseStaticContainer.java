package io.github.diogenes1oliveira.hbase2;

public final class HBaseStaticContainer {
    private static HBaseContainer container = null;

    private HBaseStaticContainer() {
        // utility class
    }

    public static synchronized HBaseContainer hBaseStaticContainer() {
        if (container == null) {
            container = new HBaseContainer().withReuse(true);
            container.start();
        }

        return container;
    }

}
