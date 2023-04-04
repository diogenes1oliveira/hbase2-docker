package io.github.diogenes1oliveira.hbase2;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.Properties;
import java.util.function.Function;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.core.IsNull.nullValue;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PropertyUtilsTest {
    static final Properties PROPS = new Properties() {{
        setProperty("nonEmptyString", "value");
        setProperty("someInteger", "42");
        setProperty("emptyString", "");
        setProperty("some.prefix1", "value");
        setProperty("some.prefix1.config1", "p1");
        setProperty("some.prefix1.config.2", "p1");
        setProperty("some.prefix2.config1", "p2");
    }};
    static final Function<String, Integer> CONVERTER = Integer::parseInt;

    @Test
    void getResourceProps_ShouldHandleNonExistingResource() {
        String resourceName = "thisResourceWontEverExist.properties";

        assertThrows(IllegalStateException.class, () -> PropertyUtils.getResourceProps(resourceName, true));
        assertThrows(IllegalStateException.class, () -> PropertyUtils.getResourceProps(resourceName)); // required by default

        assertThat(PropertyUtils.getResourceProps(resourceName, false), equalTo(new Properties()));
    }

    @Test
    void getResourceProps_ShouldLoadExistingResource() {
        String resourceName = "example.properties";
        Properties expected = new Properties() {{
            setProperty("name", "value");
        }};

        assertThat(PropertyUtils.getResourceProps(resourceName), equalTo(expected));
    }

    @ParameterizedTest
    @ValueSource(strings = {"emptyString", "noSuchProperty"})
    void getProp_ShouldHandleNonExistingProperties(String name) {
        // fail if required
        assertThrows(IllegalArgumentException.class, () -> PropertyUtils.getProp(PROPS, name, true));

        // null if not required
        assertThat(PropertyUtils.getProp(PROPS, name, false), nullValue());

        // is required by default
        assertThrows(IllegalArgumentException.class, () -> PropertyUtils.getProp(PROPS, name));

        // if a converter is passed, it is required
        assertThrows(IllegalArgumentException.class, () -> PropertyUtils.getProp(PROPS, name, CONVERTER));
    }

    @Test
    void getProp_ShouldGetStringValue() {
        assertThat(PropertyUtils.getProp(PROPS, "nonEmptyString"), equalTo("value"));
    }

    @Test
    void getProp_ShouldGetConvertedValue() {
        assertThat(PropertyUtils.getProp(PROPS, "someInteger", CONVERTER), equalTo(42));
    }

    @Test
    void getProp_ShouldThrowOnInconvertibleValue() {
        assertThrows(IllegalArgumentException.class, () -> PropertyUtils.getProp(PROPS, "nonEmptyString", CONVERTER));
    }

    @Test
    void getProps_ShouldExtractPrefixes() {
        Properties expected = new Properties() {{
            setProperty("config1", "p1");
            setProperty("config.2", "p1");
        }};
        assertThat(PropertyUtils.getProps(PROPS, "some.prefix1."), equalTo(expected));
    }

    @Test
    void mergeProps_ShouldMergeInOrder() {
        Properties props1 = new Properties() {{
            setProperty("a", "first");
            setProperty("b", "first");
        }};
        Properties props2 = new Properties() {{
            setProperty("b", "second");
        }};
        Properties expected = new Properties() {{
            setProperty("a", "first");
            setProperty("b", "second");
        }};
        assertThat(PropertyUtils.mergeProps(props1, props2), equalTo(expected));
    }
}
