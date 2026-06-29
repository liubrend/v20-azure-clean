package com.v20azure.sample.service;

import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import java.io.ByteArrayInputStream;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Azure Blob Storage gateway. The connection string and container come from env
 * (Key Vault → Container Apps). The client is built lazily so the service boots
 * without a live storage account — only blob operations require real credentials.
 */
@Service
public class BlobStorageService {

    private final String connectionString;
    private final String containerName;
    private volatile BlobContainerClient containerClient;

    public BlobStorageService(
            @Value("${azure.storage.connection-string:}") String connectionString,
            @Value("${azure.storage.container:attachments}") String containerName) {
        this.connectionString = connectionString;
        this.containerName = containerName;
    }

    /** Uploads bytes under a unique path and returns that path. */
    public String upload(String filename, byte[] content) {
        String blobPath = UUID.randomUUID() + "-" + filename;
        client().getBlobClient(blobPath)
                .upload(new ByteArrayInputStream(content), content.length, true);
        return blobPath;
    }

    /** Downloads a blob's bytes. */
    public byte[] download(String blobPath) {
        return client().getBlobClient(blobPath).downloadContent().toBytes();
    }

    /** Deletes a blob if it exists. */
    public void delete(String blobPath) {
        client().getBlobClient(blobPath).deleteIfExists();
    }

    private BlobContainerClient client() {
        BlobContainerClient local = containerClient;
        if (local == null) {
            synchronized (this) {
                local = containerClient;
                if (local == null) {
                    if (connectionString.isBlank()) {
                        throw new IllegalStateException(
                                "azure.storage.connection-string is not configured");
                    }
                    BlobServiceClient service = new BlobServiceClientBuilder()
                            .connectionString(connectionString)
                            .buildClient();
                    local = service.getBlobContainerClient(containerName);
                    if (!local.exists()) {
                        local.create();
                    }
                    containerClient = local;
                }
            }
        }
        return local;
    }
}
