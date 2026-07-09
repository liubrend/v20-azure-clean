package com.v20azure.sample;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Domain microservice: items REST API backed by Azure SQL and Azure Blob Storage. */
@SpringBootApplication
public class SampleServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(SampleServiceApplication.class, args);
    }
}
