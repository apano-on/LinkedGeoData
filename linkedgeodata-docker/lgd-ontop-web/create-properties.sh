#!/bin/bash

echo "lgd-db environment:"
env | grep -i "osm\|db\|post"

cat "/input/lgd_temp.properties" | envsubst > "/input/lgd.properties"

docker-entrypoint.sh "$@"
