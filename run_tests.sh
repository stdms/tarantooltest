#!/bin/bash

docker build -t testapp .
cid=`docker run -p 8080:8080 -p 3301:3301 -d testapp`
if [ -z "${cid}" ]; then
    echo "Docker run failed"
    exit 1
fi

prove test/*.t

docker stop ${cid}
