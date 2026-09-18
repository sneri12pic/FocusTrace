package com.stepandemianenko.focustrace.sync.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Architecture section 9 auth endpoints. Request DTOs list exactly the writable
 * fields; unknown JSON properties are rejected (spring.jackson.deserialization).
 *
 * <p>The rate-limit source is {@link HttpServletRequest#getRemoteAddr()}: with
 * {@code server.forward-headers-strategy: none} that is the socket peer, and
 * {@code X-Forwarded-For} / {@code Forwarded} cannot change it (D15).
 */
@RestController
@RequestMapping("/api/v1/auth")
class AuthController {

    private final AuthService auth;

    AuthController(AuthService auth) {
        this.auth = auth;
    }

    record RegisterRequest(
            @NotNull @Size(max = 320) @EmailAddresses.Valid String email,
            @NotNull @PasswordProcessor.Length String password) {

        @Override
        public String toString() {
            return "RegisterRequest[password=<redacted>]";
        }
    }

    /** Bounds only: a login that fails to canonicalise is still a login attempt and gets the generic 401 (D11). */
    record LoginRequest(@NotNull @Size(max = 320) String email, @NotNull @Size(max = 1024) String password) {

        @Override
        public String toString() {
            return "LoginRequest[password=<redacted>]";
        }
    }

    record RefreshTokenRequest(@NotNull @Size(max = 128) String refreshToken) {

        @Override
        public String toString() {
            return "RefreshTokenRequest[refreshToken=<redacted>]";
        }
    }

    record RegisterResponse(UUID userId) {
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    RegisterResponse register(@Valid @RequestBody RegisterRequest request, HttpServletRequest http) {
        return new RegisterResponse(auth.register(request.email(), request.password(), http.getRemoteAddr()));
    }

    @PostMapping("/login")
    AuthService.Tokens login(@Valid @RequestBody LoginRequest request, HttpServletRequest http) {
        return auth.login(request.email(), request.password(), http.getRemoteAddr());
    }

    @PostMapping("/refresh")
    AuthService.Tokens refresh(@Valid @RequestBody RefreshTokenRequest request, HttpServletRequest http) {
        return auth.refresh(request.refreshToken(), http.getRemoteAddr());
    }

    /** Authenticated (not on the public allow-list); revokes only the caller's own session. */
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(@Valid @RequestBody RefreshTokenRequest request, @AuthenticationPrincipal Jwt principal) {
        auth.logout(request.refreshToken(), UUID.fromString(principal.getSubject()));
    }
}
