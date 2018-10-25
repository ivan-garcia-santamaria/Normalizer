package com.masmovil.apigee;

import com.bazaarvoice.jolt.Chainr;
import com.bazaarvoice.jolt.JsonUtils;
import io.vertx.core.AbstractVerticle;
import io.vertx.core.Future;
import io.vertx.core.buffer.Buffer;
import io.vertx.core.http.HttpServerResponse;
import io.vertx.core.json.Json;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.RoutingContext;
import io.vertx.ext.web.client.HttpResponse;
import io.vertx.ext.web.client.WebClient;
import io.vertx.ext.web.client.WebClientOptions;
import io.vertx.ext.web.handler.BodyHandler;
import io.vertx.ext.web.handler.StaticHandler;
import lombok.extern.slf4j.Slf4j;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
public class NormalizerVerticle extends AbstractVerticle {


    private WebClient client;

    private Map<String,String> cacheSpec=new HashMap<>();
    @Override
    public void start(Future<Void> fut) {
        log.info("ahi va el normalizer");

        // Create a router object.
        Router router = Router.router(vertx);

        router.route("/v1/normalizer*").handler(BodyHandler.create());
        router.post("/v1/normalizer").handler(this::translateWithSpec);
        router.post("/v1/normalizer/:id").handler(this::translateWithoutSpec);
        router.get("/v1/normalizer/cache").handler(this::getSpecs);
        router.delete("/v1/normalizer/cache/:id").handler(this::deleteSpec);


        vertx.createHttpServer()
                .requestHandler(router::accept)
                .listen(// Retrieve the port from the configuration,
                        // default to 8080.
                        config().getInteger("http.port", 8080),
                        result -> {
                            if (result.succeeded()) {
                                fut.complete();
                            } else {
                                fut.fail(result.cause());
                            }
                        });
        // Create the web client and enable SSL/TLS with a trust store
        client = WebClient.create(vertx,
                new WebClientOptions()
                        .setSsl(true)
/*
                        .setTrustStoreOptions(new JksOptions()
                                .setPath("client-truststore.jks")
                                .setPassword("wibble")
                        )
*/
        );
    }

    private List<Object> getSpec(String spec) {
        //log.info("Retreive specifications {}",spec);
        return JsonUtils.jsonToList(spec);
    }


    private void getSpecs(RoutingContext rc) {
        rc.response()
                .putHeader("content-type", "application/json; charset=utf-8")
                .end(Json.encode(cacheSpec));
    }

    private void deleteSpec(RoutingContext rc) {
        final String id = rc.request().getParam("id");
        if (id == null) {
            rc.response().setStatusCode(400).end();
        } else {
            log.info("borrando de la cache la especificacion {}",id);
            cacheSpec.remove(id);
        }
        rc.response()
                .putHeader("content-type", "application/json; charset=utf-8")
                .end(Json.encode(cacheSpec));


    }

    private void translateWithoutSpec(RoutingContext routingContext) {
        final String id = routingContext.request().getParam("id");
        if (id == null) {
            routingContext.response().setStatusCode(400).end();
        } else {
            log.info("id de spec {}",id);
            String spec=cacheSpec.get(id);
            if (spec!=null) {
                log.info("spec cacheada");
                translateGeneric(routingContext, routingContext.getBodyAsString(), spec);
            }else {
                // Send a GET request
                client
                        .get(443, "raw.githubusercontent.com", "/ivan-garcia-santamaria/jolt-spec/master/spec_" + id + ".json")
                        .send(ar -> {
                            if (ar.succeeded()) {
                                // Obtain response
                                HttpResponse<Buffer> response = ar.result();

                                log.info("response.statusCode() {}", response.statusCode());
                                log.info("response.headers().get(\"content-type\") {}", response.headers().get("content-type"));
                                String specN=response.bodyAsString();
                                //log.info("body: {}", spec);
                                cacheSpec.put(id,specN);
                                translateGeneric(routingContext, routingContext.getBodyAsString(), specN);
                            } else {
                                log.info("Something went wrong {}", ar.cause().getMessage());
                            }
                        });
            }
        }
    }

    private void translateWithSpec(RoutingContext routingContext) {
        String payload=routingContext.getBodyAsJson().getJsonObject("data").toString();
        String spec=routingContext.getBodyAsJson().getJsonArray("spec").toString();
        translateGeneric(routingContext,payload,spec);

    }
    private void translateGeneric(RoutingContext routingContext,String payload,String spec) {

        //log.info("payload {}",payload);

        final List<Object> specs = getSpec(spec);

        //specs.forEach(object -> log.debug("{}", object));
        final Chainr chainr = Chainr.fromSpec(specs);


        Object transformed=chainr.transform(JsonUtils.jsonToObject(payload));
        //log.debug("Json.encodePrettily: {}",Json.encodePrettily(transformed));
        String transformedOutput = Json.encode(transformed);

        if ("{}".equals(transformedOutput)) {
            routingContext.response().setStatusCode(400).end();
        } else {

            //log.info("OUT: {}", transformedOutput);
            //log.info("OUT encodePrettily: {}", Json.encodePrettily(transformedOutput));

            routingContext.response()
                    .putHeader("content-type", "application/json; charset=utf-8")
                    .end(transformedOutput);
//                    .end(Json.encodePrettily(transformedOutput));
        }

    }

}
