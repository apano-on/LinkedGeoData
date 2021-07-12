#!/bin/bash

echo "lgd-ontop environment:"
cat "input/lgd_temp.properties" | envsubst > "input/lgd.properties"

#docker-entrypoint.sh "$@"
#exec "$@"
