package com.stepandemianenko.focustrace.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

/**
 * Plan criterion 17; D09 and D14. Boots the real application on a random port with
 * the settings supplied the way a deployment supplies them - as the
 * FOCUSTRACE_* variables the YAML references - and checks startup fails or
 * succeeds for the right reason, without the rejected value in any message.
 */
class StartupConfigurationTest {

    private static final List<String> VARIABLES = List.of(
            "FOCUSTRACE_DB_URL", "FOCUSTRACE_DB_USER", "FOCUSTRACE_DB_PASSWORD", "FOCUSTRACE_JWT_SECRET");

    @BeforeAll
    static void variablesNotAlreadySetInThisEnvironment() {
        // A real variable would shadow the "missing" cases and make them pass for the wrong reason.
        VARIABLES.forEach(v -> assumeTrue(System.getenv(v) == null, v + " is set in the environment"));
    }

    @Test
    void startsWithSecretOfExactly32DecodedBytes() {
        try (ConfigurableApplicationContext context = start(null, settings(secretOfBytes(32)))) {
            assertThat(context.isRunning()).isTrue();
        }
    }

    @Test
    void failsWithoutSecret() {
        Map<String, Object> settings = settings(null);
        settings.remove("FOCUSTRACE_JWT_SECRET");

        assertStartupFails(null, settings, "FOCUSTRACE_JWT_SECRET) is not set", null);
    }

    @Test
    void failsWithBlankSecret() {
        assertStartupFails(null, settings("   "), "secret", null);
    }

    @Test
    void failsWithSecretThatIsNotBase64() {
        String notBase64 = "this-is-not-base64-!!-" + "x".repeat(40);
        assertStartupFails(null, settings(notBase64), "not valid base64", notBase64);
    }

    @Test
    void failsWithSecretOf31DecodedBytes() {
        String shortSecret = secretOfBytes(31);
        assertStartupFails(null, settings(shortSecret), "at least 32 bytes", shortSecret);
    }

    @Test
    void prodStartsWhenEveryRequiredVariableIsPresent() {
        try (ConfigurableApplicationContext context = start("prod", settings(secretOfBytes(32)))) {
            assertThat(context.getEnvironment().getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
            assertThat(context.getEnvironment().getProperty("server.forward-headers-strategy")).isEqualTo("none");
            assertThat(context.getEnvironment().getProperty("server.error.include-stacktrace")).isEqualTo("never");
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"FOCUSTRACE_DB_URL", "FOCUSTRACE_DB_USER", "FOCUSTRACE_DB_PASSWORD", "FOCUSTRACE_JWT_SECRET"})
    void prodFailsWhenAVariableIsMissing(String variable) {
        Map<String, Object> settings = settings(secretOfBytes(32));
        settings.remove(variable);

        assertStartupFails("prod", settings, "missing or blank: [" + variable + "]", null);
    }

    @ParameterizedTest
    @ValueSource(strings = {"FOCUSTRACE_DB_URL", "FOCUSTRACE_DB_USER", "FOCUSTRACE_DB_PASSWORD"})
    void prodFailsWhenADatasourceVariableIsBlank(String variable) {
        Map<String, Object> settings = settings(secretOfBytes(32));
        settings.put(variable, "");

        assertStartupFails("prod", settings, "missing or blank: [" + variable + "]", null);
    }

    // --- helpers ---------------------------------------------------------------

    private static Map<String, Object> settings(String secret) {
        Map<String, Object> settings = new HashMap<>();
        settings.put("FOCUSTRACE_DB_URL", IntegrationTest.POSTGRES.getJdbcUrl());
        settings.put("FOCUSTRACE_DB_USER", IntegrationTest.POSTGRES.getUsername());
        settings.put("FOCUSTRACE_DB_PASSWORD", IntegrationTest.POSTGRES.getPassword());
        if (secret != null) {
            settings.put("FOCUSTRACE_JWT_SECRET", secret);
        }
        return settings;
    }

    private static ConfigurableApplicationContext start(String profile, Map<String, Object> settings) {
        SpringApplicationBuilder builder = new SpringApplicationBuilder(FocusTraceSyncApplication.class)
                .web(WebApplicationType.SERVLET)
                .properties(settings);
        builder.properties(Map.of("server.port", "0"));
        if (profile != null) {
            builder.profiles(profile);
        }
        return builder.run();
    }

    private static void assertStartupFails(String profile, Map<String, Object> settings, String expected, String secretValue) {
        assertThatThrownBy(() -> start(profile, settings).close())
                .satisfies(e -> {
                    String messages = String.join("\n", messages(e));
                    assertThat(messages).contains(expected);
                    if (secretValue != null) {
                        assertThat(messages).doesNotContain(secretValue);
                    }
                });
    }

    private static List<String> messages(Throwable e) {
        List<String> messages = new ArrayList<>();
        for (Throwable t = e; t != null; t = t.getCause()) {
            messages.add(String.valueOf(t.getMessage()));
        }
        return messages;
    }

    private static String secretOfBytes(int length) {
        return Base64.getEncoder().encodeToString(IntegrationTest.randomBytes(length));
    }
}
