package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;

/** Plan criterion 16a; D10. */
class LogoutIT extends SessionTestSupport {

    @Test
    void logoutRevokesOnlyThePresentedSession() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);
        Response phone = loggedIn(email, STRONG_PASSWORD);
        Response laptop = loggedIn(email, STRONG_PASSWORD);

        Response logout = logout(phone.string("refreshToken"), phone.string("accessToken"));

        assertThat(logout.status()).isEqualTo(204);
        assertThat(logout.body()).isEmpty();
        assertThat(sessionOf(phone.string("refreshToken")).get("revoked_reason")).isEqualTo("logout");
        assertThat(liveTokens(phone.string("refreshToken"))).isZero();
        assertThat(refresh(phone.string("refreshToken")).status()).isEqualTo(401);
        assertThat(refresh(laptop.string("refreshToken")).status()).isEqualTo(200);
    }

    /**
     * The access JWT has no session claim, so it cannot name a session: the refresh
     * token does, and the JWT's sub only proves ownership. Authenticating as session B
     * while presenting session A's refresh token logs out A, not B.
     */
    @Test
    void refreshTokenNotAccessTokenIdentifiesTheSession() {
        String email = uniqueEmail();
        register(email, STRONG_PASSWORD);
        Response a = loggedIn(email, STRONG_PASSWORD);
        Response b = loggedIn(email, STRONG_PASSWORD);

        assertThat(logout(a.string("refreshToken"), b.string("accessToken")).status()).isEqualTo(204);

        assertThat(sessionOf(a.string("refreshToken")).get("revoked_reason")).isEqualTo("logout");
        assertThat(sessionOf(b.string("refreshToken")).get("revoked_at")).isNull();
        assertThat(refresh(a.string("refreshToken")).status()).isEqualTo(401);
        assertThat(refresh(b.string("refreshToken")).status()).isEqualTo(200);
    }

    @Test
    void logoutIsIdempotentAndNotAnOracle() {
        Response session = newSession();
        String access = session.string("accessToken");

        assertThat(logout(session.string("refreshToken"), access).status()).isEqualTo(204);
        assertThat(logout(session.string("refreshToken"), access).status()).isEqualTo(204);
        assertThat(logout("never-issued", access).status()).isEqualTo(204);
        assertThat(sessionOf(session.string("refreshToken")).get("revoked_reason")).isEqualTo("logout");
    }

    @Test
    void anotherUsersRefreshTokenIsIgnored() {
        Response alice = newSession();
        Response mallory = newSession();

        assertThat(logout(alice.string("refreshToken"), mallory.string("accessToken")).status()).isEqualTo(204);

        assertThat(sessionOf(alice.string("refreshToken")).get("revoked_at")).isNull();
        assertThat(refresh(alice.string("refreshToken")).status()).isEqualTo(200);
    }

    @Test
    void logoutRequiresAnAccessToken() {
        Response session = newSession();

        assertThat(logout(session.string("refreshToken"), null).status()).isEqualTo(401);
        assertThat(sessionOf(session.string("refreshToken")).get("revoked_at")).isNull();
    }

    /** Accepted by D10: no access-token denylist; the JWT lives out its 15 minutes. */
    @Test
    void outstandingAccessTokenSurvivesLogoutUntilExpiry() {
        Response session = newSession();
        logout(session.string("refreshToken"), session.string("accessToken"));

        assertThat(get("/api/v1/test/whoami", session.string("accessToken")).status()).isEqualTo(200);
    }

    private Response logout(String refreshToken, String accessToken) {
        return post("/api/v1/auth/logout", Map.of("refreshToken", refreshToken), accessToken);
    }
}
