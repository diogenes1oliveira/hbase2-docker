package io.github.diogenes1oliveira.hbase2;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.IOException;
import java.io.Serializable;
import java.io.UncheckedIOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.AbstractList;
import java.util.List;

import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.instanceOf;
import static org.hamcrest.Matchers.sameInstance;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ReflectionUtilsTest {

    @Test
    void invokeUnchecked_shouldInvokeSupplierAndReturnResult() {
        Object result = ReflectionUtils.invokeUnchecked(() -> "hello");
        assertThat(result, equalTo("hello"));
    }

    @Test
    void invokeUnchecked_ShouldThrow_IfNotAccessible() throws NoSuchMethodException {
        Constructor<?> constructor = MyClass.class.getDeclaredConstructor(Void.class);

        IllegalStateException e = assertThrows(IllegalStateException.class, () -> {
            ReflectionUtils.invokeUnchecked(() -> constructor.newInstance((Object) null));
        });
        assertThat(e.getMessage(), containsString("accessible"));

        constructor.setAccessible(true);
        assertDoesNotThrow(() -> {
            ReflectionUtils.invokeUnchecked(() -> constructor.newInstance((Object) null));
        });
    }

    @Test
    void invokeUnchecked_ShouldThrow_IfNotConstructable() {
        IllegalStateException e = assertThrows(IllegalStateException.class, () -> {
            ReflectionUtils.invokeUnchecked(Serializable.class::newInstance);
        });
        assertThat(e.getMessage(), containsString("constructable"));
    }

    @Test
    void invokeUnchecked_ShouldThrow_IfBadArguments() throws NoSuchMethodException {
        Method method = MyClass.class.getDeclaredMethod("myStaticStringMethod", String.class);
        IllegalStateException e = assertThrows(IllegalStateException.class, () -> {
            ReflectionUtils.invokeUnchecked(() -> method.invoke(null, 42));
        });
        assertThat(e.getMessage(), containsString("argument"));
    }

    @Test
    void invokeUnchecked_ShouldThrowWrappedException_IfCheckedException() throws NoSuchMethodException {
        Method method = MyClass.class.getDeclaredMethod("myStaticIOMethod");
        IllegalStateException e = assertThrows(IllegalStateException.class, () -> {
            ReflectionUtils.invokeUnchecked(() -> method.invoke(null));
        });
        assertThat(e.getMessage(), containsString("checked"));
        assertThat(e.getCause(), instanceOf(IOException.class));
    }

    @Test
    void invokeUnchecked_ShouldThrowSameException_IfUncheckedException() {
        RuntimeException cause = new RuntimeException();

        RuntimeException e = assertThrows(RuntimeException.class, () -> {
            ReflectionUtils.invokeUnchecked(() -> {
                throw cause;
            });
        });
        assertThat(e, sameInstance(cause));
    }

    @Test
    void findClass_shouldReturnClassObject_whenClassNameIsValid() {
        Class<?> clazz = ReflectionUtils.findClass("java.lang.Object");
        assertThat(clazz, equalTo(Object.class));
    }

    @Test
    void findClass_shouldThrowException_whenClassNameIsInvalid() {
        assertThrows(IllegalArgumentException.class, () ->
                ReflectionUtils.findClass("com.example.NonExistentClass")
        );
    }

    @Test
    void findMethods_shouldReturnListOfMatchingMethods() {
        List<Method> methods = ReflectionUtils.findMethods(MyClass.class, "myStringMethod");
        assertThat(methods, hasSize(2));
    }

    @Test
    void findDefaultConstructor_shouldReturnDefaultConstructor() {
        Constructor<?> constructor = ReflectionUtils.findDefaultConstructor(Object.class);
        assertThat(constructor.getParameterCount(), equalTo(0));
    }

    @Test
    void findDefaultConstructor_shouldThrowException_IfNoDefaultConstructor() {
        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.findDefaultConstructor(MyClass.class);
        });
    }

    @Test
    void verifyParamTypes_shouldNotThrowException_whenParamTypesAreCorrect() throws NoSuchMethodException {
        Constructor<?> constructor = MyClass.class.getConstructor(String.class, int.class);
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyParamTypes(constructor, String.class, int.class);
        });

        Method method1 = MyClass.class.getMethod("myStringMethod", String.class);
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyParamTypes(method1, String.class);
        });

        Method method2 = MyClass.class.getMethod("myStringMethod");
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyParamTypes(method2);
        });
    }

    @Test
    void verifyParamTypes_shouldThrowException_whenParamTypesAreIncorrect() throws NoSuchMethodException {
        Constructor<?> constructor = MyClass.class.getConstructor(String.class, int.class);
        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyParamTypes(constructor, int.class, String.class);
        });
        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyParamTypes(constructor, String.class);
        });

        Method method = MyClass.class.getMethod("myStringMethod", String.class);

        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyParamTypes(method, int.class, String.class, String.class);
        });
    }

    @ParameterizedTest
    @ValueSource(classes = {Integer.class, Number.class, Object.class})
    void verifyReturnType_shouldNotThrowException_whenReturnTypeIsCorrect(Class<?> clazz) throws NoSuchMethodException {
        Method method = MyClass.class.getMethod("myNumberMethod");
        assertDoesNotThrow(() -> ReflectionUtils.verifyReturnType(method, clazz));
    }

    @ParameterizedTest
    @ValueSource(classes = {int.class, String.class})
    void verifyReturnType_shouldThrowException_whenReturnTypeIsIncorrect(Class<?> clazz) throws NoSuchMethodException {
        Method method = MyClass.class.getMethod("myNumberMethod");

        assertThrows(IllegalArgumentException.class, () ->
                ReflectionUtils.verifyReturnType(method, clazz)
        );
    }

    @Test
    void verifyStatic_shouldNotThrowException_whenMethodIsStatic() throws NoSuchMethodException {
        Method method = MyClass.class.getMethod("myStaticStringMethod", String.class);
        assertDoesNotThrow(() -> ReflectionUtils.verifyStatic(method));
    }

    @Test
    void verifyStatic_shouldThrowException_whenMethodIsNotStatic() throws NoSuchMethodException {
        Method method = MyClass.class.getMethod("myStringMethod", String.class);
        assertThrows(IllegalArgumentException.class, () ->
                ReflectionUtils.verifyStatic(method)
        );
    }

    @ParameterizedTest
    @ValueSource(classes = {Object.class, Number.class, Integer.class})
    void verifyAssignableTo_shouldNotThrowException_whenTypesMatch(Class<?> clazz) {
        assertDoesNotThrow(() -> ReflectionUtils.verifyAssignableTo(Integer.class, clazz));
    }

    @ParameterizedTest
    @ValueSource(classes = {Double.class, int.class, MyClass.class})
    void verifyAssignableTo_shouldThrowException_whenTypesDontMatch(Class<?> clazz) {
        assertThrows(IllegalArgumentException.class, () ->
                ReflectionUtils.verifyAssignableTo(Integer.class, clazz)
        );
    }

    @Test
    void verifyNonChecked_shouldNotThrowException_whenNoCheckedExceptions() throws NoSuchMethodException {
        Constructor<?> constructor = MyClass.class.getConstructor(String.class, int.class);
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyNonChecked(constructor);
        });

        Method method1 = MyClass.class.getMethod("myNonCheckedMethod");
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyNonChecked(method1);
        });

        Method method2 = MyClass.class.getMethod("myStringMethod");
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyNonChecked(method2);
        });
    }

    @Test
    void verifyNonChecked_shouldThrowException_whenNoCheckedExceptions() throws NoSuchMethodException {
        Constructor<?> constructor = MyClass.class.getConstructor(String.class, int.class, Throwable.class);
        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyNonChecked(constructor);
        });
        Method method = MyClass.class.getMethod("myStaticIOMethod");

        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyNonChecked(method);
        });
    }

    @ParameterizedTest
    @ValueSource(classes = {AbstractList.class, Serializable.class, Object[].class, int.class, void.class})
    void verifyConstructable_shouldThrowException_whenNotConstructible(Class<?> clazz) {
        assertThrows(IllegalArgumentException.class, () -> {
            ReflectionUtils.verifyConstructable(clazz);
        });
    }

    @ParameterizedTest
    @ValueSource(classes = {MyClass.class, Object.class})
    void verifyConstructable_shouldNotThrowException_whenConstructible(Class<?> clazz) {
        assertDoesNotThrow(() -> {
            ReflectionUtils.verifyConstructable(clazz);
        });
    }

    static class MyClass {
        public MyClass(String s, int i) {
        }

        public MyClass(String s, int i, Throwable throwable) throws Exception {
        }

        private MyClass(Void v) {

        }

        public String myStringMethod(String s) {
            return "";
        }

        public String myStringMethod() {
            return "";
        }

        public void myNonCheckedMethod() throws IllegalArgumentException {
        }

        public Integer myNumberMethod() {
            return 42;
        }

        public static void myStaticIOMethod() throws IOException {
            throw new IOException();
        }

        public static void myStaticStringMethod(String s) {
        }
    }

}