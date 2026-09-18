package com.stepandemianenko.focustrace.sync.common;

import org.springframework.http.HttpStatus;

/**
 * An expected, client-facing failure. Its detail is written for the client and
 * therefore never carries a credential, a hash or an internal identifier.
 */
public final class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String field;
    private final long retryAfterSeconds;

    private ApiException(HttpStatus status, String detail, String field, long retryAfterSeconds) {
        // No cause and no stack trace: these are control-flow outcomes, not faults.
        super(detail, null, false, false);
        this.status = status;
        this.field = field;
        this.retryAfterSeconds = retryAfterSeconds;
    }

    /** One body for every authentication failure (D11, baseline section 7). */
    public static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Authentication failed.", null, 0);
    }

    public static ApiException conflict(String detail) {
        return new ApiException(HttpStatus.CONFLICT, detail, null, 0);
    }

    public static ApiException invalidField(String field, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, message, field, 0);
    }

    /** Deliberately says nothing about which limit tripped or whether an account exists (D15). */
    public static ApiException tooManyRequests(long retryAfterSeconds) {
        return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "Too many requests. Try again later.", null, retryAfterSeconds);
    }

    public HttpStatus status() {
        return status;
    }

    public String field() {
        return field;
    }

    public long retryAfterSeconds() {
        return retryAfterSeconds;
    }
}
