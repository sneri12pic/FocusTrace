package com.stepandemianenko.focustrace.sync.common;

import java.util.List;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;
import org.springframework.context.EnvironmentAware;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * D14: under {@code prod} every connection setting and secret must be present and
 * non-blank, and startup fails before anything tries to use them.
 *
 * <p>A bean-factory post-processor rather than a validated properties bean because
 * of ordering: an unresolved {@code ${FOCUSTRACE_DB_URL}} is bound as that literal
 * string, and a blank password would be handed to the DataSource as-is - against a
 * trust-authenticated database that connects. This runs before any ordinary bean,
 * so the DataSource and Flyway never see a missing or blank value.
 */
@Component
@Profile("prod")
class ProductionConfiguration implements BeanFactoryPostProcessor, EnvironmentAware {

    /** FOCUSTRACE_NETWORK_MODE: production states its network edge explicitly (D20). */
    static final List<String> REQUIRED = List.of(
            "FOCUSTRACE_DB_URL", "FOCUSTRACE_DB_USER", "FOCUSTRACE_DB_PASSWORD", "FOCUSTRACE_JWT_SECRET",
            "FOCUSTRACE_NETWORK_MODE");

    private Environment environment;

    @Override
    public void setEnvironment(Environment environment) {
        this.environment = environment;
    }

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
        List<String> missing = REQUIRED.stream()
                .filter(name -> {
                    String value = environment.getProperty(name);
                    return value == null || value.isBlank();
                })
                .toList();
        if (!missing.isEmpty()) {
            // Names only, never values.
            throw new IllegalStateException("prod profile: required settings missing or blank: " + missing);
        }
    }
}
