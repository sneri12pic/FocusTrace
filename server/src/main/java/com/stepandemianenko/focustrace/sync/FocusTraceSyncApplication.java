package com.stepandemianenko.focustrace.sync;

import java.time.Clock;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
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
