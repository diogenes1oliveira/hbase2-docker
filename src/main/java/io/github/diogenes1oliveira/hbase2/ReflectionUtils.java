package io.github.diogenes1oliveira.hbase2;

import java.lang.reflect.Constructor;
import java.lang.reflect.Executable;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.Arrays;
import java.util.List;

import static java.util.stream.Collectors.toList;

public final class ReflectionUtils {
    private ReflectionUtils() {
        // utility class
    }

    public interface ReflectionInvoker {
        Object invoke() throws IllegalAccessException, InvocationTargetException, InstantiationException;
    }

    public static Class<?> findClass(String className) {
        try {
            return Class.forName(className);
        } catch (ClassNotFoundException e) {
            throw new IllegalArgumentException("Class not found: " + className, e);
        }
    }

    public static List<Method> findMethods(Class<?> type, String name) {
        return Arrays.stream(type.getDeclaredMethods())
                     .filter(method -> method.getName().equals(name))
                     .collect(toList());
    }

    public static Constructor<?> findDefaultConstructor(Class<?> type) {
        try {
            return type.getDeclaredConstructor();
        } catch (NoSuchMethodException e) {
            throw new IllegalArgumentException("Class doesn't have a default constructor: " + type, e);
        }
    }

    public static Object invokeUnchecked(ReflectionInvoker supplier) {
        try {
            return supplier.invoke();
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("Bad argument types for reflected code", e);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException("Reflected code is not accessible", e);
        } catch (InstantiationException e) {
            throw new IllegalStateException("Reflected class is not constructable", e);
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof RuntimeException) {
                throw (RuntimeException) cause;
            }
            throw new IllegalStateException("Unexpected checked exception", cause);
        }
    }

    public static void verifyParamTypes(Method method, Class<?>... paramTypes) {
        verifyParamTypes(method, "Method", paramTypes);
    }

    public static void verifyParamTypes(Constructor<?> constructor, Class<?>... paramTypes) {
        verifyParamTypes(constructor, "Constructor", paramTypes);
    }

    private static void verifyParamTypes(Executable executable, String executableType, Class<?>... paramTypes) {
        Class<?>[] types = executable.getParameterTypes();

        if (types.length != paramTypes.length) {
            throw new IllegalArgumentException(String.format(
                    "%s with unexpected parameter count (expected %d): %s", executableType, paramTypes.length, executable
            ));
        }

        for (int i = 0; i < types.length; ++i) {
            Class<?> type = types[i];
            Class<?> paramType = paramTypes[i];

            if (!paramType.isAssignableFrom(type)) {
                throw new IllegalArgumentException(String.format(
                        "%s with unexpected parameter type #%d (expected %s): %s",
                        executableType, i, paramType, executable
                ));
            }
        }
    }

    public static void verifyReturnType(Method method, Class<?> expectedReturnType) {
        if (!expectedReturnType.isAssignableFrom(method.getReturnType())) {
            throw new IllegalArgumentException(String.format(
                    "Method doesn't return a value compatible with %s: %s", expectedReturnType, method
            ));
        }
    }

    public static void verifyStatic(Method method) {
        if (!Modifier.isStatic(method.getModifiers())) {
            throw new IllegalArgumentException("Method is not static: " + method);
        }
    }

    public static void verifyConstructable(Class<?> type) {
        if (Modifier.isAbstract(type.getModifiers())
                || Modifier.isInterface(type.getModifiers())
                || type.isArray()
                || type.isPrimitive()
                || type == void.class) {
            throw new IllegalArgumentException("Class is not constructable: " + type);
        }
    }

    public static void verifyAssignableTo(Class<?> type, Class<?> targetType) {
        if (!targetType.isAssignableFrom(type)) {
            throw new IllegalArgumentException(String.format(
                    "Class is not assignable to %s: %s" + targetType, type
            ));
        }
    }

    private static void verifyNonChecked(Executable executable, String executableType) {
        for (Class<?> type : executable.getExceptionTypes()) {
            if (!RuntimeException.class.isAssignableFrom(type)) {
                throw new IllegalArgumentException(String.format(
                        "%s declares a checked exception: %s", executableType, executable
                ));
            }
        }
    }

    public static void verifyNonChecked(Method method) {
        verifyNonChecked(method, "Method");
    }

    public static void verifyNonChecked(Constructor<?> constructor) {
        verifyNonChecked(constructor, "Constructor");
    }

}
