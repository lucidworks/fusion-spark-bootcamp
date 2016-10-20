#!/bin/bash

FUSION_HOME=/opt/fusion-dev/3.0.0
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

# the directory where you cloned the spark-solr project:
SPARK_SOLR_HOME=/Users/timpotter/dev/lw/projects/spark-solr

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"
