package com.stepandemianenko.focustrace.sync.auth;

import com.stepandemianenko.focustrace.sync.common.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * D18: charges a {@link AuthRateLimiter.PerUser} handler to its bucket before any
 * argument is resolved, so an invalid or oversized upload body still costs a token
 * and is never parsed once the caller is over budget.
 *
 * <p>Runs after the security filter chain: an unauthenticated request is already a
 * 401 and never reaches a bucket. The key is the principal name, which the JWT
 * converter sets to the verified {@code sub} of an existing account - never request
 * input.
 */
@Component
class PerUserRateLimitInterceptor implements HandlerInterceptor, WebMvcConfigurer {

    private final AuthRateLimiter rateLimiter;

    PerUserRateLimitInterceptor(AuthRateLimiter rateLimiter) {
        this.rateLimiter = rateLimiter;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(this);
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (handler instanceof HandlerMethod method) {
            AuthRateLimiter.PerUser limit = method.getMethodAnnotation(AuthRateLimiter.PerUser.class);
            if (limit != null) {
                Principal principal = request.getUserPrincipal();
                if (principal == null) {
                    throw ApiException.unauthorized();
                }
                rateLimiter.acquire(limit.value(), principal.getName());
            }
        }
        return true;
    }
}
