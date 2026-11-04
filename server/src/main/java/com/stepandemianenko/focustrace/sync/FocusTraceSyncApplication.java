package com.stepandemianenko.focustrace.sync;

import com.stepandemianenko.focustrace.sync.common.SyncLimits;
import java.time.Clock;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableConfigurationProperties(SyncLimits.class)
// AuthRetention's nightly purge (architecture 6.4).
@EnableScheduling
public class FocusTraceSyncApplication {

    public static void main(String[] args) {
        SpringApplication.run(FocusTraceSyncApplication.class, args);
    }

    /** UTC wall clock; tests replace it to pin date boundaries. */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}
