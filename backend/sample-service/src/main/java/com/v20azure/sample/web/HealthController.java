package com.v20azure.sample.web;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Service identity + liveness. Kept dependency-free (no DB) so the L2 test gate and
 * the container image-smoke check pass on a fresh scaffold.
 */
@RestController
public class HealthController {

    private static final String SERVICE = "v20-Azure-clean-teamsEnabled";

    /** Liveness probe used by the Container Apps health check. */
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    /** Service identity at the root path. */
    @GetMapping("/")
    public Map<String, String> root() {
        return Map.of("service", SERVICE, "status", "ok");
    }
}
