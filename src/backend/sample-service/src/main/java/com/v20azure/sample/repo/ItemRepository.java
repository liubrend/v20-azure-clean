package com.v20azure.sample.repo;

import com.v20azure.sample.domain.Item;
import org.springframework.data.jpa.repository.JpaRepository;

/** Spring Data JPA repository over the items table in Azure SQL. */
public interface ItemRepository extends JpaRepository<Item, Long> {
}
