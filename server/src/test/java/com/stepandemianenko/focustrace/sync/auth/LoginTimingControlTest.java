package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * D11: a login that finds no account still costs one Argon2id verification, so
 * "no row, instant reply" is not an account oracle. Response equality is covered
 * by LoginIT; this proves the work is actually done (removing the dummy
 * verification from AuthService fails here).
 */
class LoginTimingControlTest {

    private final UserRepository users = mock(UserRepository.class);
    private PasswordProcessor passwords;
    private AuthService auth;

    @BeforeEach
    void setUp() {
        passwords = spy(new PasswordProcessor());
        auth = new AuthService(users, passwords, mock(AuthSessions.class), mock(AccessTokens.class),
                mock(AuthRateLimiter.class));
        when(users.findByEmail(anyString())).thenReturn(Optional.empty());
    }

    @Test
    void unknownAccountRunsOneDummyVerification() {
        assertThatThrownBy(() -> auth.login("nobody@example.com", "Some-Password-123", "127.0.0.1"))
                .isInstanceOf(ApiException.class);

        verify(passwords, times(1)).matchDummy("Some-Password-123");
    }

    @Test
    void invalidIdentifierRunsOneDummyVerification() {
        assertThatThrownBy(() -> auth.login("\tnot valid", "Some-Password-123", "127.0.0.1"))
                .isInstanceOf(ApiException.class);

        verify(passwords, times(1)).matchDummy("Some-Password-123");
    }

    /** D17 is registration-only: login never consults the blocklist, and still burns one verification. */
    @Test
    void blocklistedPasswordOnUnknownAccountRunsDummyVerificationNotTheBlocklist() {
        assertThatThrownBy(() -> auth.login("nobody@example.com", "PasswordPassword", "127.0.0.1"))
                .isInstanceOf(ApiException.class);

        verify(passwords, times(1)).matchDummy("PasswordPassword");
        verify(passwords, never()).isTooCommon(anyString(), anyString());
    }
}
