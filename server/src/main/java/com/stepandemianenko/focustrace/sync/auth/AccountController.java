package com.stepandemianenko.focustrace.sync.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * D19 account deletion; authenticated. A {@code POST} to a named action rather than
 * {@code DELETE /account}: the request carries the current password, and a body on
 * {@code DELETE} has no defined semantics (RFC 9110 9.3.5), so intermediaries may
 * drop or reject it. The account is always the token's {@code sub}; the body holds
 * only the password, and unknown properties (a {@code userId}, an email) are a 400.
 */
@RestController
class AccountController {

    private final AuthService auth;

    AccountController(AuthService auth) {
        this.auth = auth;
    }

    /** Bounds as login: a wrong password is a 403 decided by verification, not by shape. */
    record DeleteAccountRequest(@NotNull @Size(max = 1024) String password) {

        @Override
        public String toString() {
            return "DeleteAccountRequest[password=<redacted>]";
        }
    }

    @PostMapping("/api/v1/account/delete")
    @AuthRateLimiter.PerUser(AuthRateLimiter.Bucket.ACCOUNT_DELETE_PER_USER)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(@Valid @RequestBody DeleteAccountRequest request, @AuthenticationPrincipal Jwt principal) {
        auth.deleteAccount(UUID.fromString(principal.getSubject()), request.password());
    }
}
