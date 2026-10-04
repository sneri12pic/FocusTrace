package com.stepandemianenko.focustrace.sync.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/** An account. Never returned through REST; {@code passwordHash} has no response field anywhere. */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Canonical form only (D03); the database CHECK rejects anything else. */
    @Column(nullable = false, updatable = false)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    protected User() {
    }

    User(String canonicalEmail, String passwordHash) {
        this.email = canonicalEmail;
        this.passwordHash = passwordHash;
    }

    public UUID getId() {
        return id;
    }

    String getPasswordHash() {
        return passwordHash;
    }
}
