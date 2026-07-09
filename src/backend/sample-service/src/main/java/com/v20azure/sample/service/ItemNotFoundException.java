package com.v20azure.sample.service;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** Thrown when an item id does not exist; maps to HTTP 404. */
@ResponseStatus(HttpStatus.NOT_FOUND)
public class ItemNotFoundException extends RuntimeException {

    public ItemNotFoundException(Long id) {
        super("item not found: " + id);
    }
}
