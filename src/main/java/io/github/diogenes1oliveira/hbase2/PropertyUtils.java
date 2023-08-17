package io.github.diogenes1oliveira.hbase2;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.NoSuchFileException;
import java.util.Map;
import java.util.Properties;
import java.util.function.Function;

public final class PropertyUtils {
    private PropertyUtils() {
        // utility class
    }

    public static Properties getResourceProps(String resourceName, boolean required) {
        try (InputStream stream = HBaseContainer.class.getClassLoader().getResourceAsStream(resourceName)) {
            Properties props = new Properties();

            if (stream == null) {
                if (required) {
                    throw new NoSuchFileException("Resource not found: " + resourceName);
                } else {
                    return props;
                }
            }

            props.load(stream);
            return props;
        } catch (IOException e) {
            throw new IllegalStateException("Failed to load resource: " + resourceName, e);
        }
    }

    public static Properties getResourceProps(String resourceName) {
        return getResourceProps(resourceName, true);
    }

    public static String getProp(Properties props, String name, boolean required) {
        String value = props.getProperty(name);
        if (value == null || value.isEmpty()) {
            if (required) {
                throw new IllegalArgumentException("No value for property: " + name);
            }
            return null;
        }

        return value;
    }

    public static String getProp(Properties props, String name) {
        return getProp(props, name, true);
    }

    public static <T> T getProp(Properties props, String name, Function<String, T> converter) {
        String value = props.getProperty(name);
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException("No value for property: " + name);
        }

        T converted;
        try {
            converted = converter.apply(value);
        } catch (RuntimeException e) {
            throw new IllegalArgumentException("Invalid value for property: " + name, e);
        }

        return converted;
    }

    public static Properties getProps(Properties props, String prefix) {
        Properties result = new Properties();

        for (String name : props.stringPropertyNames()) {
            if (name.startsWith(prefix)) {
                String restOfName = name.substring(prefix.length());
                String value = props.getProperty(name);
                result.setProperty(restOfName, value);
            }
        }

        return result;
    }

    public static Properties mergeProps(Properties... allProps) {
        Properties result = new Properties();

        for (Properties props : allProps) {
            result.putAll(props);
        }

        return result;
    }

    public static Properties envToProps(Map<String, String> env, boolean toLowerCase) {
        Properties result = new Properties();

        for (Map.Entry<String, String> entry : env.entrySet()) {
            String envName = entry.getKey();
            if(toLowerCase) {
                envName = envName.toLowerCase();
            }
            String value = entry.getValue();

            String propName = envToProp(envName);
            result.setProperty(propName, value);
        }

        return result;
    }

    public static Properties envToProps(Map<String, String> env) {
        return envToProps(env, true);
    }

    public static String envToProp(String envName) {
        return envName.replace("___", "$")
                      .replace("__", "-")
                      .replace("_", ".")
                      .replace("$", "_");
    }

    public static String propToEnv(String propName) {
        return propName.replace("_", "___")
                       .replace("-", "__")
                       .replace(".", "_");
    }
}
