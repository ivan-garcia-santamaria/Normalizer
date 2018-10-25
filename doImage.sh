#!/bin/bash

mvn clean package -DskipTests

tagGC=`docker images | grep vertx-normalizer |awk -F" " '{if ($1=="gcr.io/tranformacion-it-lab/vertx-normalizer") {print $3}}'`
if [ "$tagGC" != "" ]
then
	echo "Borrando la imagen anterior "$tagGC
	docker rmi $tagGC -f
fi

echo "Creando la imagen...."
docker build -t vertx-normalizer .

tag=`docker images | grep vertx-normalizer |awk -F" " '{if ($1=="vertx-normalizer") {print $3}}'`
echo "Creando tag imagen: "$tag
docker tag $tag gcr.io/tranformacion-it-lab/vertx-normalizer:1.0.0

echo "Subiendo a Google Cloud..."
docker push gcr.io/tranformacion-it-lab/vertx-normalizer:1.0.0

pod=`kubectl get pod | grep vertx-normalizer | awk -F" " '{print $1}'`
if [ "$pod" != "" ]
then
	echo "Borrando el POD "$pod
	kubectl delete pod $pod
else
fi
watch kubectl get pod

pod=`kubectl get pod | grep vertx-normalizer | awk -F" " '{print $1}'`

kubectl logs -f $pod
