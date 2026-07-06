package com.v20azure.sample.agent;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import org.springframework.stereotype.Component;

/**
 * ASI02 (Tool Misuse) + ASI03 (Identity &amp; Privilege Abuse) runtime guard.
 * Route every tool call an agent can make through {@link #call} instead of
 * invoking the tool directly: it enforces a zero-trust allowlist of tool
 * names, per-tool argument/boundary validation, and a short-lived credential
 * scoped to one tool so a hijacked agent can't reuse it elsewhere.
 *
 * <p>No agent or tool-calling framework exists in this codebase yet; register
 * policies with {@link #register} wherever one is added.
 */
@Component
public class ToolCallGate {

    private final Map<String, ToolPolicy> policies = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    public interface ToolPolicy {
        /** @return null if the call is allowed, or a reason string if it must be denied. */
        String validate(Map<String, Object> args);

        Object execute(Map<String, Object> args);
    }

    public record ScopedCredential(String token, String toolName, Instant expiresAt) {
        boolean isValidFor(String toolName) {
            return this.toolName.equals(toolName) && Instant.now().isBefore(expiresAt);
        }
    }

    public static class ToolCallDeniedException extends RuntimeException {
        public ToolCallDeniedException(String message) {
            super(message);
        }
    }

    public void register(String toolName, ToolPolicy policy) {
        policies.put(toolName, policy);
    }

    public ScopedCredential mintCredential(String toolName, Duration ttl) {
        byte[] raw = new byte[16];
        random.nextBytes(raw);
        return new ScopedCredential(
                HexFormat.of().formatHex(raw), toolName, Instant.now().plus(ttl));
    }

    public Object call(String toolName, ScopedCredential credential, Map<String, Object> args) {
        ToolPolicy policy = policies.get(toolName);
        if (policy == null) {
            throw new ToolCallDeniedException("unknown tool: " + toolName);
        }
        if (!credential.isValidFor(toolName)) {
            throw new ToolCallDeniedException(
                    "credential invalid or expired for tool: " + toolName);
        }
        String denyReason = policy.validate(args);
        if (denyReason != null) {
            throw new ToolCallDeniedException(
                    "boundary check failed for " + toolName + ": " + denyReason);
        }
        return policy.execute(args);
    }

    /**
     * Convenience policy builder for the common case: validate with a
     * predicate-like function, execute with another. Kept as a static factory
     * rather than a lambda-friendly constructor so call sites read as
     * declarations of policy, not inline logic.
     */
    public static ToolPolicy policy(
            Set<String> allowedKeys,
            Function<Map<String, Object>, String> validator,
            Function<Map<String, Object>, Object> executor) {
        return new ToolPolicy() {
            @Override
            public String validate(Map<String, Object> args) {
                if (!allowedKeys.containsAll(args.keySet())) {
                    return "unexpected arguments: " + args.keySet();
                }
                return validator.apply(args);
            }

            @Override
            public Object execute(Map<String, Object> args) {
                return executor.apply(args);
            }
        };
    }
}
