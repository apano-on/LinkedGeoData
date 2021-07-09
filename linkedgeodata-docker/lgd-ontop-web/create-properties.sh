#!/bin/bash
set -eu

env | grep -i "ontop\|db\|post"

cat input/lgd_temp.properties | envsubst > input/lgd.properties
