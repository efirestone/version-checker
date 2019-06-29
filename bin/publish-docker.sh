#!/bin/bash

if [ -z "$1" ]; then
	echo "A version number must be specified as the only argument"
	exit 1
fi

IMAGE_NAME=version-checker-$1
docker build ./ -t $IMAGE_NAME

TAG=efirestone/version-checker:$1
docker tag $IMAGE_NAME $TAG
docker push $TAG

TAG=efirestone/version-checker:latest
docker tag $IMAGE_NAME $TAG
docker push $TAG
