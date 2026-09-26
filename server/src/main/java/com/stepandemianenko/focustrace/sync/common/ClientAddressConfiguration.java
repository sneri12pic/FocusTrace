package com.stepandemianenko.focustrace.sync.common;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.apache.catalina.valves.RemoteIpValve;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

/**
 * D20: who may tell the server a client's address. The one resolved address is
 * {@code HttpServletRequest.getRemoteAddr()} everywhere - rate limiting (D15) and
 * security events alike; nothing parses a forwarding header itself.
 *
 * <ul>
 *   <li>{@code direct}: the socket peer. Every forwarding header is ignored.
 *   <li>{@code trusted-proxy}: Tomcat's {@link RemoteIpValve} replaces the address
 *       from {@code X-Forwarded-For}, but only for a request whose socket peer is one
 *       of the listed proxies. Walking the header right to left, listed proxies are
 *       skipped and the first other entry is the client; everything left of it is
 *       ignored, so a client cannot choose its key by prepending entries.
 *       {@code Forwarded} and {@code X-Real-IP} are never read.
 * </ul>
 *
 * <p>Proxies are exact IP literals, never names, ranges or patterns. The valve would
 * compile anything without a {@code /} as a regex (so {@code 10.0.0.5} would also
 * trust {@code 10.0.0.15}) and would resolve a CIDR candidate through DNS, so each
 * literal is validated here and handed over as a quoted, exact-match regex.
 * {@code server.forward-headers-strategy} must stay {@code none}: Boot's own valve
 * would trust every private range by default.
 */
@Configuration(proxyBeanMethods = false)
@EnableConfigurationProperties(ClientAddressConfiguration.Network.class)
class ClientAddressConfiguration {

    enum Mode { DIRECT, TRUSTED_PROXY }

    @ConfigurationProperties("focustrace.network")
    record Network(Mode mode, List<String> trustedProxies) {
    }

    private static final Pattern IPV4 = Pattern.compile(
            "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}");
    /** Hex digits, colons and an optional embedded IPv4 tail; no zone, prefix or name. */
    private static final Pattern IPV6 = Pattern.compile("[0-9A-Fa-f:.]*:[0-9A-Fa-f:.]*");

    @Bean
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> clientAddressCustomizer(
            Network network, Environment environment) {
        String strategy = environment.getProperty("server.forward-headers-strategy", "none");
        if (!"none".equalsIgnoreCase(strategy)) {
            throw new IllegalStateException("server.forward-headers-strategy must be 'none'; trust forwarded"
                    + " client addresses only through focustrace.network.mode=trusted-proxy (D20)");
        }
        if (network.mode() == null) {
            throw new IllegalStateException("focustrace.network.mode must be 'direct' or 'trusted-proxy' (D20)");
        }
        List<String> proxies = network.trustedProxies() == null ? List.of() : network.trustedProxies().stream()
                .map(String::trim)
                .filter(entry -> !entry.isEmpty())
                .toList();
        if (network.mode() == Mode.DIRECT) {
            if (!proxies.isEmpty()) {
                throw new IllegalStateException(
                        "focustrace.network.trusted-proxies is set but mode is 'direct' (D20)");
            }
            return factory -> { };
        }
        if (proxies.isEmpty()) {
            throw new IllegalStateException(
                    "focustrace.network.mode 'trusted-proxy' requires focustrace.network.trusted-proxies (D20)");
        }
        String exactProxies = proxies.stream()
                .map(ClientAddressConfiguration::canonical)
                .map(Pattern::quote)
                .collect(Collectors.joining("|"));
        return factory -> {
            RemoteIpValve valve = new RemoteIpValve();
            valve.setInternalProxies(exactProxies);
            valve.setTrustedProxies(null);
            valve.setRemoteIpHeader("X-Forwarded-For");
            valve.setProtocolHeader("X-Forwarded-Proto");
            factory.addEngineValves(valve);
        };
    }

    /** The address as Tomcat reports a socket peer, from an IP literal only (no DNS lookup). */
    static String canonical(String entry) {
        if (!IPV4.matcher(entry).matches() && !IPV6.matcher(entry).matches()) {
            throw new IllegalStateException("focustrace.network.trusted-proxies entry is not an exact IP address: '"
                    + entry + "' (no host names, ranges or patterns; D20)");
        }
        InetAddress address;
        try {
            address = InetAddress.getByName(entry); // a literal: parsed, never resolved
        } catch (UnknownHostException e) {
            throw new IllegalStateException(
                    "focustrace.network.trusted-proxies entry is not a valid IP address: '" + entry + "' (D20)");
        }
        if (address.isAnyLocalAddress()) {
            throw new IllegalStateException(
                    "focustrace.network.trusted-proxies entry is the unspecified address: '" + entry + "' (D20)");
        }
        return address.getHostAddress();
    }
}
