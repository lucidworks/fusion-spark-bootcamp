#!/bin/bash

FUSION_HOME=/opt/fusion/3.0.0
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

#curl -X POST -H 'Content-type: application/json' -d '{"password":"password123"}' http://$FUSION/api

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"
