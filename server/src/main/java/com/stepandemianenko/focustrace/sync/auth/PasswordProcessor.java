package com.stepandemianenko.focustrace.sync.auth;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.DelegatingPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * The single password-processing path (D01, D02, D17). Registration and login both
 * reach the encoder through {@link #normalize}, so they hash byte-identical input.
 *
 * <p>No method here logs, stores or echoes a password.
 */
@Component
public class PasswordProcessor {

    /** D02, policy. Unicode code points, measured after NFC. */
    public static final int MIN_LENGTH = 15;
    public static final int MAX_LENGTH = 128;

    /**
     * Checked before NFC so an absurd input is never normalised. Generous on purpose:
     * a legitimate 128-code-point password arrives as at most ~3 UTF-16 units per
     * code point even fully decomposed, well under this bound.
     */
    private static final int MAX_RAW_CHARS = MAX_LENGTH * 8;

    static final String BLOCKLIST_RESOURCE = "auth/common-passwords.txt";
    private static final int MAX_BLOCKLIST_ENTRIES = 100_000;
    private static final String ENTRIES_HEADER = "# entries: ";

    private final PasswordEncoder encoder;
    private final Set<String> blocklist;
    private final String dummyHash;

    public PasswordProcessor() {
        this.encoder = createEncoder();
        this.blocklist = loadBlocklist(new ClassPathResource(BLOCKLIST_RESOURCE));
        // D11: unknown-account logins verify against this, so they cost one Argon2id run too.
        this.dummyHash = encoder.encode(UUID.randomUUID().toString());
    }

    /**
     * D01, policy: Argon2id, m=19456 KiB, t=2, p=1, 16-byte salt, 32-byte hash, stored
     * with the {@code {argon2}} prefix. Explicit, never the library's defaults.
     */
    static PasswordEncoder createEncoder() {
        Argon2PasswordEncoder argon2 = new Argon2PasswordEncoder(16, 32, 1, 19456, 2);
        return new DelegatingPasswordEncoder("argon2", Map.of("argon2", argon2));
    }

    /**
     * D02: Unicode NFC and nothing else. Not trimmed, not case-folded, not NFKC, not
     * truncated. The only transformation a password ever receives.
     */
    static String normalize(String raw) {
        return Normalizer.normalize(raw, Normalizer.Form.NFC);
    }

    /** D02 length violation for {@code raw}, or {@code null}. Measured in code points after NFC. */
    static String lengthViolation(String raw) {
        if (!isWellFormed(raw)) {
            return "must be valid Unicode text";
        }
        if (raw.length() > MAX_RAW_CHARS) {
            return "must be at most " + MAX_LENGTH + " characters";
        }
        String normalized = normalize(raw);
        int codePoints = normalized.codePointCount(0, normalized.length());
        if (codePoints < MIN_LENGTH) {
            return "must be at least " + MIN_LENGTH + " characters";
        }
        if (codePoints > MAX_LENGTH) {
            return "must be at most " + MAX_LENGTH + " characters";
        }
        return null;
    }

    /**
     * D17: true when the password is on the local blocklist or equals the local part
     * of the account's email. Compared lower-cased, which covers the exact match
     * because every entry is stored lower-case.
     *
     * <p>Admission control for a <em>prospective</em> password only: call it wherever a
     * new password is established (registration; any future change/reset flow). Never
     * on login, and never on a current password being verified.
     */
    boolean isTooCommon(String raw, String canonicalEmail) {
        String folded = normalize(raw).toLowerCase(Locale.ROOT);
        String localPart = canonicalEmail.substring(0, canonicalEmail.indexOf('@'));
        return blocklist.contains(folded) || folded.equals(localPart);
    }

    String hash(String raw) {
        return encoder.encode(normalize(raw));
    }

    /**
     * A malformed password (lone surrogate) can never match - registration rejects it -
     * and Argon2's UTF-8 conversion would throw on it, so it costs one dummy
     * verification and answers false like any other wrong password.
     */
    boolean matches(String raw, String storedHash) {
        if (!isWellFormed(raw)) {
            matchDummy(raw);
            return false;
        }
        return encoder.matches(normalize(raw), storedHash);
    }

    /** Burns one verification so a missing account is not answered faster than a wrong password. */
    void matchDummy(String raw) {
        encoder.matches(normalize(wellFormed(raw)), dummyHash);
    }

    /** False when {@code s} holds an unpaired UTF-16 surrogate, which JSON escapes can deliver. */
    static boolean isWellFormed(String s) {
        return s.codePoints().noneMatch(PasswordProcessor::isSurrogate);
    }

    private static boolean isSurrogate(int codePoint) {
        return codePoint >= Character.MIN_SURROGATE && codePoint <= Character.MAX_SURROGATE;
    }

    private static String wellFormed(String s) {
        return isWellFormed(s) ? s : s.codePoints()
                .map(cp -> isSurrogate(cp) ? 0xFFFD : cp)
                .collect(StringBuilder::new, StringBuilder::appendCodePoint, StringBuilder::append)
                .toString();
    }

    /**
     * Loads the versioned blocklist. Strict UTF-8, bounded, every entry lower-case
     * and NFC, no duplicates, and the count must equal the header's {@code entries}
     * line - any deviation fails startup rather than silently shrinking the list.
     */
    static Set<String> loadBlocklist(Resource resource) {
        CharsetDecoder utf8 = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), utf8))) {
            Set<String> entries = new HashSet<>();
            Integer declared = null;
            boolean inHeader = true;
            int lineNumber = 0;
            String line;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                if (inHeader && line.startsWith("#")) {
                    if (line.startsWith(ENTRIES_HEADER)) {
                        declared = Integer.valueOf(line.substring(ENTRIES_HEADER.length()).strip());
                    }
                    continue;
                }
                inHeader = false;
                boolean wellFormed = !line.isEmpty()
                        && line.length() <= MAX_RAW_CHARS
                        && line.equals(line.toLowerCase(Locale.ROOT))
                        && line.equals(normalize(line));
                if (!wellFormed) {
                    throw malformed("malformed entry at line " + lineNumber);
                }
                if (entries.size() >= MAX_BLOCKLIST_ENTRIES) {
                    throw malformed("more than " + MAX_BLOCKLIST_ENTRIES + " entries");
                }
                if (!entries.add(line)) {
                    throw malformed("duplicate entry at line " + lineNumber);
                }
            }
            if (declared == null || declared != entries.size()) {
                throw malformed("declared " + declared + " entries, found " + entries.size());
            }
            return Set.copyOf(entries);
        } catch (IOException | NumberFormatException e) {
            throw malformed("unreadable: " + e.getClass().getSimpleName());
        }
    }

    private static IllegalStateException malformed(String reason) {
        return new IllegalStateException("Password blocklist " + BLOCKLIST_RESOURCE + " is invalid: " + reason);
    }

    /** D02 enforced by Bean Validation on the registration DTO. {@code null} is left to {@code @NotNull}. */
    @Target(ElementType.FIELD)
    @Retention(RetentionPolicy.RUNTIME)
    @Constraint(validatedBy = Length.Validator.class)
    public @interface Length {
        String message() default "";

        Class<?>[] groups() default {};

        Class<? extends Payload>[] payload() default {};

        class Validator implements ConstraintValidator<Length, String> {
            @Override
            public boolean isValid(String value, ConstraintValidatorContext context) {
                String violation = value == null ? null : lengthViolation(value);
                if (violation == null) {
                    return true;
                }
                context.disableDefaultConstraintViolation();
                context.buildConstraintViolationWithTemplate(violation).addConstraintViolation();
                return false;
            }
        }
    }
}
