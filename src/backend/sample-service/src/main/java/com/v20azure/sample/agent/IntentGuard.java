package com.v20azure.sample.agent;

import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * ASI01 (Agent Goal Hijack) runtime guard. No agent exists in this codebase yet
 * ({@code com.v20azure.sample} is CRUD-only) &mdash; this is scaffolding so that
 * whichever service first accepts natural-language input into an LLM call has
 * a guard to call before that input reaches the model, instead of bolting one
 * on after an incident.
 *
 * <p>Two layers, cheap-first: a pattern scan that catches common injection
 * phrasing for free, then an optional {@link IntentJudge} for semantic checks
 * that don't match a known phrasing. No {@link IntentJudge} implementation
 * exists yet because no LLM client is wired into this repo; plug one in when
 * one is.
 */
@Component
public class IntentGuard {

    private static final List<Pattern> INJECTION_PATTERNS =
            List.of(
                            "ignore (all )?(previous|prior|above) instructions",
                            "disregard (your|the) (system prompt|instructions)",
                            "you are now",
                            "new instructions?:",
                            "reveal (your|the) system prompt",
                            "do anything now",
                            "jailbreak")
                    .stream()
                    .map(p -> Pattern.compile(p, Pattern.CASE_INSENSITIVE))
                    .toList();

    private final Optional<IntentJudge> judge;

    public IntentGuard() {
        this(Optional.empty());
    }

    public IntentGuard(Optional<IntentJudge> judge) {
        this.judge = judge;
    }

    public record IntentCheckResult(boolean allowed, String reason) {}

    /** Declares what the calling agent is allowed to be asked to do. */
    public record IntentCapsule(String taskDescription, List<String> allowedTopics) {}

    public IntentCheckResult check(String text, IntentCapsule capsule) {
        for (Pattern pattern : INJECTION_PATTERNS) {
            if (pattern.matcher(text).find()) {
                return new IntentCheckResult(
                        false, "matched known injection pattern: " + pattern.pattern());
            }
        }
        return judge.map(j -> j.classify(text, capsule))
                .orElse(new IntentCheckResult(true, "no pattern match"));
    }

    /** Semantic second pass, backed by whatever LLM client the agent uses. */
    public interface IntentJudge {
        IntentCheckResult classify(String text, IntentCapsule capsule);
    }
}
