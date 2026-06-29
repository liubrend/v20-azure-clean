package com.v20azure.sample.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.v20azure.sample.domain.Item;
import com.v20azure.sample.repo.ItemRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** Pure unit tests: repository and blob store mocked with Mockito, no Spring, no DB. */
@ExtendWith(MockitoExtension.class)
class ItemServiceTest {

    @Mock
    private ItemRepository repository;

    @Mock
    private BlobStorageService blobStorage;

    @InjectMocks
    private ItemService service;

    @Test
    void createSavesItem() {
        when(repository.save(any(Item.class))).thenAnswer(inv -> inv.getArgument(0));

        Item created = service.create("widget", "a thing");

        assertThat(created.getName()).isEqualTo("widget");
        verify(repository).save(any(Item.class));
    }

    @Test
    void findByIdMissingThrows() {
        when(repository.findById(42L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(42L))
                .isInstanceOf(ItemNotFoundException.class);
    }

    @Test
    void attachUploadsBlobAndRecordsPath() {
        Item item = new Item("widget", "a thing");
        when(repository.findById(1L)).thenReturn(Optional.of(item));
        when(blobStorage.upload(anyString(), any(byte[].class))).thenReturn("abc-doc.pdf");
        when(repository.save(any(Item.class))).thenAnswer(inv -> inv.getArgument(0));

        Item updated = service.attach(1L, "doc.pdf", new byte[] {1, 2, 3});

        assertThat(updated.getBlobPath()).isEqualTo("abc-doc.pdf");
        verify(blobStorage).upload("doc.pdf", new byte[] {1, 2, 3});
    }

    @Test
    void deleteWithoutBlobSkipsBlobStore() {
        Item item = new Item("widget", "a thing");
        when(repository.findById(1L)).thenReturn(Optional.of(item));

        service.delete(1L);

        verify(blobStorage, never()).delete(anyString());
        verify(repository).delete(item);
    }
}
