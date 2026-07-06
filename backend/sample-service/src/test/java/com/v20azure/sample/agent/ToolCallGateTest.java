package com.v20azure.sample.agent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.v20azure.sample.agent.ToolCallGate.ScopedCredential;
import com.v20azure.sample.agent.ToolCallGate.ToolCallDeniedException;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ToolCallGateTest {

    private final ToolCallGate gate = new ToolCallGate();

    @BeforeEach
    void registerEchoTool() {
        gate.register(
                "echo",
                ToolCallGate.policy(
                        Set.of("message"),
                        args -> {
                            String message = (String) args.get("message");
                            return message.length() > 100 ? "message too long" : null;
                        },
                        args -> "echo: " + args.get("message")));
    }

    @Test
    void allowsValidCallWithinPolicy() {
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofSeconds(30));

        Object result = gate.call("echo", credential, Map.of("message", "hello"));

        assertThat(result).isEqualTo("echo: hello");
    }

    @Test
    void deniesUnknownTool() {
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofSeconds(30));

        assertThatThrownBy(() -> gate.call("delete_file", credential, Map.of()))
                .isInstanceOf(ToolCallDeniedException.class)
                .hasMessageContaining("unknown tool");
    }

    @Test
    void deniesCredentialScopedToDifferentTool() {
        gate.register(
                "delete_file", ToolCallGate.policy(Set.of("path"), args -> null, args -> "deleted"));
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofSeconds(30));

        assertThatThrownBy(() -> gate.call("delete_file", credential, Map.of("path", "x")))
                .isInstanceOf(ToolCallDeniedException.class)
                .hasMessageContaining("credential invalid");
    }

    @Test
    void deniesExpiredCredential() throws InterruptedException {
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofMillis(1));
        Thread.sleep(10);

        assertThatThrownBy(() -> gate.call("echo", credential, Map.of("message", "hi")))
                .isInstanceOf(ToolCallDeniedException.class)
                .hasMessageContaining("expired");
    }

    @Test
    void deniesCallViolatingBoundaryCheck() {
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofSeconds(30));
        String tooLong = "x".repeat(200);

        assertThatThrownBy(() -> gate.call("echo", credential, Map.of("message", tooLong)))
                .isInstanceOf(ToolCallDeniedException.class)
                .hasMessageContaining("boundary check failed");
    }

    @Test
    void deniesUnexpectedArguments() {
        ScopedCredential credential = gate.mintCredential("echo", Duration.ofSeconds(30));

        assertThatThrownBy(
                        () ->
                                gate.call(
                                        "echo",
                                        credential,
                                        Map.of("message", "hi", "extra", "not allowed")))
                .isInstanceOf(ToolCallDeniedException.class)
                .hasMessageContaining("unexpected arguments");
    }
}
