package com.v20azure.sample.web;

import com.v20azure.sample.domain.Item;
import com.v20azure.sample.service.ItemService;
import com.v20azure.sample.web.dto.ItemRequest;
import com.v20azure.sample.web.dto.ItemResponse;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** RESTful CRUD for items plus an Azure Blob attachment endpoint. */
@RestController
@RequestMapping("/items")
public class ItemController {

    private final ItemService service;

    public ItemController(ItemService service) {
        this.service = service;
    }

    @GetMapping
    public List<ItemResponse> list() {
        return service.findAll().stream().map(ItemResponse::from).toList();
    }

    @GetMapping("/{id}")
    public ItemResponse get(@PathVariable Long id) {
        return ItemResponse.from(service.findById(id));
    }

    @PostMapping
    public ResponseEntity<ItemResponse> create(@Valid @RequestBody ItemRequest request) {
        Item created = service.create(request.name(), request.description());
        return ResponseEntity
                .created(URI.create("/items/" + created.getId()))
                .body(ItemResponse.from(created));
    }

    @PutMapping("/{id}")
    public ItemResponse update(@PathVariable Long id, @Valid @RequestBody ItemRequest request) {
        return ItemResponse.from(service.update(id, request.name(), request.description()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }

    /** Uploads an attachment to Azure Blob Storage and links it to the item. */
    @PostMapping("/{id}/attachment")
    public ItemResponse attach(@PathVariable Long id, @RequestParam("file") MultipartFile file)
            throws java.io.IOException {
        Item updated = service.attach(id, file.getOriginalFilename(), file.getBytes());
        return ItemResponse.from(updated);
    }
}
