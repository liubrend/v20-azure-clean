package com.v20azure.sample.web.dto;

import jakarta.validation.constraints.NotBlank;

/** Inbound payload for creating/updating an item. */
public record ItemRequest(
        @NotBlank String name,
        String description) {
}
