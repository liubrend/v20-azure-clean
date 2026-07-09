package com.v20azure.sample.agent;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * ASI06 (Memory &amp; Context Poisoning) runtime guard. Gate every write into
 * long-term memory / a vector store through {@link #checkBeforeIngest} before
 * it's ingested, and re-verify with {@link #verifyOnRead} before content
 * pulled back out of memory is used &mdash; a signature mismatch on read means
 * the store was altered after ingestion (e.g. a direct write bypassing this
 * guard), not just that ingestion was skipped.
 *
 * <p>No memory store exists in this codebase yet; wire this in wherever one is
 * added.
 */
@Component
public class MemoryIntegrityGuard {

    private static final List<Pattern> INSTRUCTION_INJECTION_PATTERNS =
            List.of(
                            "when (this is |you are )?retrieved",
                            "if (you are |this is )?(an? )?(ai|assistant|agent)",
                            "ignore (all )?(previous|prior|above) instructions",
                            "system prompt")
                    .stream()
                    .map(p -> Pattern.compile(p, Pattern.CASE_INSENSITIVE))
                    .toList();

    // Blank by default so the service boots without a live secret (same pattern as
    // BLOB_CONNECTION_STRING in application.yml); real environments set
    // AGENT_MEMORY_SIGNING_KEY via Key Vault. Signing fails closed at first use,
    // not at bean construction -- nothing calls this guard yet, so refusing to
    // boot the whole service over an unset key nobody uses would be the wrong trade.
    private final String signingKey;

    public MemoryIntegrityGuard(@Value("${agent.memory.signing-key:}") String signingKey) {
        this.signingKey = signingKey;
    }

    public record MemoryChunk(String text, String source) {}

    public record IngestDecision(boolean allowed, String reason, String signature) {
        static IngestDecision block(String reason) {
            return new IngestDecision(false, reason, null);
        }
    }

    public IngestDecision checkBeforeIngest(MemoryChunk chunk) {
        for (Pattern pattern : INSTRUCTION_INJECTION_PATTERNS) {
            if (pattern.matcher(chunk.text()).find()) {
                return IngestDecision.block(
                        "content matched instruction-injection pattern: " + pattern.pattern());
            }
        }
        String signature = sign(chunk.text(), chunk.source());
        return new IngestDecision(true, "sanitized + signed", signature);
    }

    public IngestDecision verifyOnRead(MemoryChunk chunk, String storedSignature) {
        String expected = sign(chunk.text(), chunk.source());
        if (!constantTimeEquals(expected, storedSignature)) {
            return IngestDecision.block("signature mismatch -- possible tampering");
        }
        return new IngestDecision(true, "signature valid", storedSignature);
    }

    private String sign(String text, String source) {
        if (signingKey == null || signingKey.isBlank()) {
            throw new IllegalStateException(
                    "agent.memory.signing-key is not set -- do not sign with a default key");
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(signingKey.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] raw = mac.doFinal((source + ":" + text).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(raw);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException("HMAC signing failed", e);
        }
    }

    private boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) {
            return false;
        }
        int diff = 0;
        for (int i = 0; i < a.length(); i++) {
            diff |= a.charAt(i) ^ b.charAt(i);
        }
        return diff == 0;
    }
}
