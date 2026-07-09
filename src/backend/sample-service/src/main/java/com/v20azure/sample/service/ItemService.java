package com.v20azure.sample.service;

import com.v20azure.sample.domain.Item;
import com.v20azure.sample.repo.ItemRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Application logic for items. Pure orchestration over the repository and blob store. */
@Service
public class ItemService {

    private final ItemRepository repository;
    private final BlobStorageService blobStorage;

    public ItemService(ItemRepository repository, BlobStorageService blobStorage) {
        this.repository = repository;
        this.blobStorage = blobStorage;
    }

    @Transactional(readOnly = true)
    public List<Item> findAll() {
        return repository.findAll();
    }

    @Transactional(readOnly = true)
    public Item findById(Long id) {
        return repository.findById(id).orElseThrow(() -> new ItemNotFoundException(id));
    }

    @Transactional
    public Item create(String name, String description) {
        return repository.save(new Item(name, description));
    }

    @Transactional
    public Item update(Long id, String name, String description) {
        Item item = findById(id);
        item.setName(name);
        item.setDescription(description);
        return repository.save(item);
    }

    @Transactional
    public void delete(Long id) {
        Item item = findById(id);
        if (item.getBlobPath() != null) {
            blobStorage.delete(item.getBlobPath());
        }
        repository.delete(item);
    }

    /** Stores an attachment in Blob Storage and records its path on the item. */
    @Transactional
    public Item attach(Long id, String filename, byte[] content) {
        Item item = findById(id);
        String blobPath = blobStorage.upload(filename, content);
        item.setBlobPath(blobPath);
        return repository.save(item);
    }
}
