package com.stepandemianenko.focustrace.sync.device;

import com.stepandemianenko.focustrace.sync.auth.AuthRateLimiter;
import com.stepandemianenko.focustrace.sync.common.ApiException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Architecture section 9 device endpoints; authenticated (not on the public
 * allow-list). The owner is always the token's {@code sub}. The request DTO has
 * no owner or timestamp field, and unknown JSON properties are a 400, so neither
 * can be supplied (baseline section 4, rules 4 and 8).
 */
@RestController
@RequestMapping("/api/v1/devices")
class DeviceController {

    private final Devices devices;

    DeviceController(Devices devices) {
        this.devices = devices;
    }

    record RegisterDeviceRequest(
            @NotNull UUID deviceId,
            // No control characters, no unpaired UTF-16 surrogate: the JDBC driver
            // would store a lone surrogate as '?' rather than what was sent.
            @NotBlank @Size(max = 100) @Pattern(regexp = "[^\\p{Cc}\\p{Cs}]*") String displayName,
            @NotNull @Pattern(regexp = "android|windows") String platform) {
    }

    /**
     * 201 for a new installation, 200 for the caller's own re-registration, 409 for
     * another account's UUID, 403 for a new installation past the device quota (D18).
     */
    @PostMapping
    @AuthRateLimiter.PerUser(AuthRateLimiter.Bucket.DEVICE_REGISTER_PER_USER)
    ResponseEntity<Devices.DeviceResponse> register(
            @Valid @RequestBody RegisterDeviceRequest request, @AuthenticationPrincipal Jwt principal) {
        // Architecture section 3: an app-generated random UUID, never a hardware-derived one.
        UUID deviceId = request.deviceId();
        if (deviceId.version() != 4 || deviceId.variant() != 2) {
            throw ApiException.invalidField("deviceId", "must be a random (version 4) UUID");
        }
        Devices.Registration registration = devices.register(
                UUID.fromString(principal.getSubject()), deviceId, request.displayName(), request.platform());
        return ResponseEntity.status(registration.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(registration.device());
    }

    @GetMapping
    List<Devices.DeviceResponse> list(@AuthenticationPrincipal Jwt principal) {
        return devices.list(UUID.fromString(principal.getSubject()));
    }
}
