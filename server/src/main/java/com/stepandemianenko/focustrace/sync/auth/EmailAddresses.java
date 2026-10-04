package com.stepandemianenko.focustrace.sync.auth;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * D03: the account identifier. One canonicalisation, used by registration, login
 * and every repository lookup. The database CHECK {@code users_email_canonical}
 * states the same invariant: printable ASCII only, lower-case.
 */
public final class EmailAddresses {

    /** RFC 5321 path limits. */
    static final int MAX_LENGTH = 254;
    private static final int MAX_LOCAL_PART_LENGTH = 64;

    /**
     * WHATWG HTML "valid e-mail address". Its alphabet is a subset of U+0021-U+007E,
     * so a match also proves the address has no whitespace, control or non-ASCII
     * character - D03 step 2.
     */
    private static final Pattern SYNTAX = Pattern.compile(
            "[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
                    + "@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
                    + "(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*");

    private EmailAddresses() {
    }

    /**
     * The canonical identity for {@code raw}, or empty when it is not a valid
     * address. Invalid input is rejected, never repaired.
     */
    public static Optional<String> canonicalize(String raw) {
        if (raw == null) {
            return Optional.empty();
        }
        String stripped = stripSpaces(raw);
        if (!isValidSyntax(stripped)) {
            return Optional.empty();
        }
        // Locale.ROOT: the default-locale overload maps I to dotless i under tr.
        return Optional.of(stripped.toLowerCase(Locale.ROOT));
    }

    /**
     * D03 step 1: removes leading and trailing U+0020 SPACE and nothing else. Not
     * String.trim() (all chars <= U+0020) and not String.strip() (Unicode whitespace).
     */
    static String stripSpaces(String raw) {
        int start = 0;
        int end = raw.length();
        while (start < end && raw.charAt(start) == ' ') {
            start++;
        }
        while (end > start && raw.charAt(end - 1) == ' ') {
            end--;
        }
        return raw.substring(start, end);
    }

    /** Syntax only; separate from canonicalisation. Length is checked before the regex runs. */
    static boolean isValidSyntax(String address) {
        int at = address.indexOf('@');
        return address.length() <= MAX_LENGTH
                && at > 0
                && at <= MAX_LOCAL_PART_LENGTH
                && SYNTAX.matcher(address).matches();
    }

    /** REST-layer syntax validation for request DTOs. {@code null} is left to {@code @NotNull}. */
    @Target(ElementType.FIELD)
    @Retention(RetentionPolicy.RUNTIME)
    @Constraint(validatedBy = Valid.Validator.class)
    public @interface Valid {
        String message() default "must be a valid email address";

        Class<?>[] groups() default {};

        Class<? extends Payload>[] payload() default {};

        class Validator implements ConstraintValidator<Valid, String> {
            @Override
            public boolean isValid(String value, ConstraintValidatorContext context) {
                return value == null || canonicalize(value).isPresent();
            }
        }
    }
}
