package com.v20azure.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.route.Route;
import org.springframework.cloud.gateway.route.RouteLocator;
import reactor.core.publisher.Flux;

/** Proves the gateway loads and exposes the sample-service route. */
@SpringBootTest
class GatewayRoutingTest {

    @Autowired
    private RouteLocator routeLocator;

    @Test
    void exposesSampleServiceRoute() {
        Flux<Route> routes = routeLocator.getRoutes();
        List<String> ids = routes.map(Route::getId).collectList().block();

        assertThat(ids).contains("sample-service");
    }
}
