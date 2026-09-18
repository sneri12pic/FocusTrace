package com.stepandemianenko.focustrace.sync.common;

import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * The one REST error model: RFC 9457 problem details (architecture section 9,
 * baseline section 15). Framework exceptions (malformed JSON, wrong method, ...)
 * are handled by the superclass, whose details are generic.
 *
 * <p>Nothing here echoes a rejected value: a rejected value may be a password.
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ProblemDetail> handleApiException(ApiException ex) {
        ProblemDetail body = ProblemDetail.forStatusAndDetail(ex.status(), ex.getMessage());
        HttpHeaders headers = new HttpHeaders();
        if (ex.field() != null) {
            body.setProperty("errors", List.of(fieldError(ex.field(), ex.getMessage())));
        }
        if (ex.status() == HttpStatus.UNAUTHORIZED) {
            headers.set(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        }
        if (ex.status() == HttpStatus.TOO_MANY_REQUESTS) {
            headers.set(HttpHeaders.RETRY_AFTER, Long.toString(ex.retryAfterSeconds()));
        }
        return ResponseEntity.status(ex.status()).headers(headers).body(body);
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        ProblemDetail body = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Request validation failed.");
        // Field name and constraint message only; never FieldError.getRejectedValue().
        body.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
                .map(e -> fieldError(e.getField(), e.getDefaultMessage()))
                .toList());
        return ResponseEntity.badRequest().body(body);
    }

    /** Anything unexpected: generic 500, full diagnostic in the log only, tied by correlation id. */
    @ExceptionHandler(Exception.class)
    ResponseEntity<ProblemDetail> handleUnexpected(Exception ex) {
        String correlationId = MDC.get(RequestIdFilter.MDC_KEY);
        log.error("Unhandled exception, correlationId={}", correlationId, ex);
        ProblemDetail body = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Internal error.");
        body.setProperty("correlationId", correlationId);
        return ResponseEntity.internalServerError().body(body);
    }

    private static Map<String, String> fieldError(String field, String message) {
        return Map.of("field", field, "message", message);
    }
}
