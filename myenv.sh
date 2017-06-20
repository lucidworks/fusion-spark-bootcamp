#!/bin/bash

FUSION_HOME=/Users/timpotter/dev/lw/sstk-local/fusion-dev/3.1-SNAPSHOT
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

curl -X POST -H 'Content-type: application/json' -d '{"password":"password123"}' http://$FUSION/api

# the directory where you cloned the spark-solr project:
SPARK_SOLR_HOME=/Users/timpotter/dev/lw/projects/spark-solr

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"
