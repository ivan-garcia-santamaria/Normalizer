#!/bin/bash

nombre=$1

mvn clean package -DskipTests

tagGC=`docker images | grep $nombre |awk -v nombre=$nombre -F" " '{if ($1=="gcr.io/tranformacion-it-lab/"nombre) {print $3}}'`
if [ "$tagGC" != "" ]
then
	echo "Borrando la imagen anterior "$tagGC
	docker rmi $tagGC -f
fi

echo "Creando la imagen...."
docker build -t $nombre .

tag=`docker images | grep $nombre |awk -v nombre=$nombre -F" " '{if ($1==nombre) {print $3}}'`
echo "Creando tag imagen: "$tag
docker tag $tag gcr.io/tranformacion-it-lab/$nombre:1.0.0

echo "Subiendo a Google Cloud..."
docker push gcr.io/tranformacion-it-lab/$nombre:1.0.0

pod=`kubectl get pod | grep $nombre | awk -F" " '{print $1}'`
if [ "$pod" != "" ]
then
	echo "Borrando el POD "$pod
	kubectl delete pod $pod
else
	echo "Creamos deployment"
	kubectl run $nombre --replicas=1 --labels="app=$nombre" --image=gcr.io/tranformacion-it-lab/$nombre:1.0.0 --port=8080
	echo "Creamos el service"
	kubectl expose deployment $nombre --target-port=8080 --type=ClusterIP --name=$nombre

fi
watch kubectl get pod

pod=`kubectl get pod | grep $nombre | awk -F" " '{print $1}'`

kubectl logs -f $pod
