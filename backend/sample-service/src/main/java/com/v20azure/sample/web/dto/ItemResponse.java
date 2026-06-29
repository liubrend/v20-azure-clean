package com.v20azure.sample.web.dto;

import com.v20azure.sample.domain.Item;
import java.time.Instant;

/** Outbound representation of an item. */
public record ItemResponse(
        Long id,
        String name,
        String description,
        String blobPath,
        Instant createdAt) {

    public static ItemResponse from(Item item) {
        return new ItemResponse(
                item.getId(),
                item.getName(),
                item.getDescription(),
                item.getBlobPath(),
                item.getCreatedAt());
    }
}
