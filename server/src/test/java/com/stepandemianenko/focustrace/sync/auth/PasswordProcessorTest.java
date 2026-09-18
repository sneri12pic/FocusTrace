package com.stepandemianenko.focustrace.sync.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.ClassPathResource;

/** D02 and D17 unit-level checks. */
class PasswordProcessorTest {

    /** The count recorded in the resource header for version 1. */
    private static final int BLOCKLIST_V1_ENTRIES = 10_912;

    @Test
    void blocklistLoadsAndMatchesItsRecordedVersion() {
        Set<String> entries = PasswordProcessor.loadBlocklist(new ClassPathResource(PasswordProcessor.BLOCKLIST_RESOURCE));

        assertThat(entries).hasSize(BLOCKLIST_V1_ENTRIES);
        assertThat(entries).contains("passwordpassword", "focustracepassword");
        assertThat(entries).allSatisfy(e -> assertThat(e.codePointCount(0, e.length())).isBetween(15, 128));
    }

    @Test
    void malformedBlocklistFailsPredictably() {
        assertThatThrownBy(() -> load("# entries: 2\nonlyoneentryhere\n")).hasMessageContaining("declared 2");
        assertThatThrownBy(() -> load("onlyoneentryhere\n")).hasMessageContaining("declared null");
        assertThatThrownBy(() -> load("# entries: 1\nUpperCaseEntryHere\n")).hasMessageContaining("malformed");
        assertThatThrownBy(() -> load("# entries: 2\nsameentryhere\nsameentryhere\n")).hasMessageContaining("duplicate");
        assertThatThrownBy(() -> load("# entries: 1\n\n")).hasMessageContaining("malformed");
        assertThatThrownBy(() -> load("# entries: x\n")).hasMessageContaining("unreadable");
        assertThatThrownBy(() -> PasswordProcessor.loadBlocklist(new ByteArrayResource(
                new byte[] {'#', ' ', 'e', '\n', (byte) 0xC3, 0x28, '\n'}))).hasMessageContaining("unreadable");
    }

    @Test
    void lengthBoundariesInCodePointsAfterNfc() {
        assertThat(PasswordProcessor.lengthViolation("a".repeat(14))).contains("at least 15");
        assertThat(PasswordProcessor.lengthViolation("a".repeat(15))).isNull();
        assertThat(PasswordProcessor.lengthViolation("a".repeat(128))).isNull();
        assertThat(PasswordProcessor.lengthViolation("a".repeat(129))).contains("at most 128");
        assertThat(PasswordProcessor.lengthViolation("😀".repeat(15))).isNull();
        assertThat(PasswordProcessor.lengthViolation("😀".repeat(129))).contains("at most 128");
        assertThat(PasswordProcessor.lengthViolation("é".repeat(15))).isNull();
        assertThat(PasswordProcessor.lengthViolation("é".repeat(14))).contains("at least 15");
        assertThat(PasswordProcessor.lengthViolation("a".repeat(100_000))).contains("at most 128");
    }

    @Test
    void normalisationIsNfcOnly() {
        assertThat(PasswordProcessor.normalize("  Café  ")).isEqualTo("  Café  ");
        // NFKC would fold these; NFC must not.
        assertThat(PasswordProcessor.normalize("ﬁ①Ａ")).isEqualTo("ﬁ①Ａ");
    }

    @Test
    void hashingAndVerificationShareNormalisation() {
        PasswordProcessor passwords = new PasswordProcessor();
        String hash = passwords.hash("Café-Correct-Horse");

        assertThat(hash).startsWith("{argon2}$argon2id$v=19$m=19456,t=2,p=1$");
        assertThat(passwords.matches("Café-Correct-Horse", hash)).isTrue();
        assertThat(passwords.matches("café-correct-horse", hash)).isFalse();
        assertThat(passwords.matches(" Café-Correct-Horse", hash)).isFalse();
    }

    @Test
    void tooCommonChecksBlocklistAndEmailLocalPart() {
        PasswordProcessor passwords = new PasswordProcessor();

        assertThat(passwords.isTooCommon("PASSWORDPASSWORD", "a@example.com")).isTrue();
        assertThat(passwords.isTooCommon("SomebodyVeryUnique", "somebodyveryunique@example.com")).isTrue();
        assertThat(passwords.isTooCommon("Violet-Quarry-Lantern-8214", "a@example.com")).isFalse();
    }

    private static Set<String> load(String content) {
        return PasswordProcessor.loadBlocklist(new ByteArrayResource(content.getBytes(StandardCharsets.UTF_8)));
    }
}
