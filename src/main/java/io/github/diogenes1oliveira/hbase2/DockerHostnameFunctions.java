package io.github.diogenes1oliveira.hbase2;

import com.github.dockerjava.api.DockerClient;
import com.github.dockerjava.api.command.InfoCmd;
import com.github.dockerjava.api.model.Info;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.List;

import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.findClass;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.findDefaultConstructor;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.findMethods;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.invokeUnchecked;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyAssignableTo;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyConstructable;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyNonChecked;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyParamTypes;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyReturnType;
import static io.github.diogenes1oliveira.hbase2.ReflectionUtils.verifyStatic;

public final class DockerHostnameFunctions {

    private DockerHostnameFunctions() {
        // utility class
    }

    public static DockerHostnameFunction constant(String hostname) {
        return d -> hostname;
    }

    public static DockerHostnameFunction localhost() {
        return constant("localhost");
    }

    public static DockerHostnameFunction dockerHostname() {
        return dockerClient -> {
            try (InfoCmd infoCmd = dockerClient.infoCmd()) {
                Info info = infoCmd.exec();
                return info.getName();
            }
        };
    }

    public static DockerHostnameFunction fromPropertySpec(String spec) {
        String[] parts = spec.split("#", 2);
        if (parts.length == 1) {
            return fromClass(parts[0]);
        } else {
            return fromMethod(parts[0], parts[1]);
        }
    }

    public static DockerHostnameFunction fromClass(String className) {
        Class<?> type = findClass(className);
        verifyAssignableTo(type, DockerHostnameFunction.class);
        verifyConstructable(type);

        Constructor<?> constructor = findDefaultConstructor(type);
        verifyNonChecked(constructor);

        constructor.setAccessible(true);
        return (DockerHostnameFunction) invokeUnchecked(constructor::newInstance);
    }

    public static DockerHostnameFunction fromMethod(String className, String methodName) {
        Class<?> type = findClass(className);
        List<Method> methods = findMethods(type, methodName);
        String debugName = className + "#" + methodName;

        if (methods.isEmpty()) {
            throw new IllegalArgumentException("No method " + debugName);
        } else if (methods.size() > 1) {
            throw new IllegalArgumentException("Too many overloads for method " + debugName);
        }

        Method method = methods.get(0);
        verifyStatic(method);
        verifyNonChecked(method);
        method.setAccessible(true);

        switch (method.getParameterCount()) {
            case 0:
                verifyParamTypes(method);
                verifyReturnType(method, DockerHostnameFunction.class);

                return (DockerHostnameFunction) invokeUnchecked(() -> method.invoke(null));
            case 1:
                verifyParamTypes(method, DockerClient.class);
                verifyReturnType(method, String.class);

                return dockerClient -> (String) invokeUnchecked(() -> method.invoke(null, dockerClient));
            default:
                throw new IllegalArgumentException("Too many parameters for method " + debugName);
        }
    }

}
