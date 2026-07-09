package com.v20azure.sample.web;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.v20azure.sample.domain.Item;
import com.v20azure.sample.service.ItemNotFoundException;
import com.v20azure.sample.service.ItemService;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** REST API slice test: ItemService mocked, MVC layer exercised end-to-end. */
@WebMvcTest(ItemController.class)
class ItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ItemService service;

    @Test
    void listReturnsItems() throws Exception {
        when(service.findAll()).thenReturn(List.of(new Item("widget", "a thing")));

        mockMvc.perform(get("/items"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("widget"));
    }

    @Test
    void createValidatesBlankName() throws Exception {
        mockMvc.perform(post("/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void createReturns201() throws Exception {
        when(service.create(anyString(), anyString())).thenReturn(new Item("widget", "a thing"));

        mockMvc.perform(post("/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"widget\",\"description\":\"a thing\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("widget"));
    }

    @Test
    void getMissingReturns404() throws Exception {
        when(service.findById(anyLong())).thenThrow(new ItemNotFoundException(99L));

        mockMvc.perform(get("/items/99"))
                .andExpect(status().isNotFound());
    }
}
