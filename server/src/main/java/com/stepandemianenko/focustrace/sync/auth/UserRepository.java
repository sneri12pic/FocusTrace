package com.stepandemianenko.focustrace.sync.auth;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** The argument must come from {@link EmailAddresses#canonicalize} (D03). */
    Optional<User> findByEmail(String canonicalEmail);
}
