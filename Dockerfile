# Extend vert.x image
FROM vertx/vertx3

#                                                       (1)
#ENV VERTICLE_NAME com.masmovil.hello.MyFirstVerticle
ENV VERTICLE_NAME com.masmovil.apigee.NormalizerVerticle
ENV VERTICLE_FILE target/normalizer-app-1.0-SNAPSHOT-fat.jar

# Set the location of the verticles
ENV VERTICLE_HOME /usr/verticles

EXPOSE 8080

# Copy your verticle to the container                   (2)
COPY $VERTICLE_FILE $VERTICLE_HOME/

# Launch the verticle
WORKDIR $VERTICLE_HOME
ENTRYPOINT ["sh", "-c"]
CMD ["exec vertx run $VERTICLE_NAME -cp $VERTICLE_HOME/*"]