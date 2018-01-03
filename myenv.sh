#!/bin/bash

FUSION_HOME=/Users/timpotter/dev/lw/sstk-local/fc-jan-2018/fusion/4.0.0-alpha2
#FUSION_HOME=/Users/timpotter/dev/lw/sstk-local/fusion-dev/4.0.0-SNAPSHOT
#FUSION_HOME=/Users/timpotter/dev/lw/sstk-local/fusion-dev/3.1.0
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

curl -X POST -H 'Content-type: application/json' -d '{"password":"password123"}' http://$FUSION/api

#curl -s -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d '{"id":"bootcamp", "name":"bootcamp","description":"dev","properties":{"headerImageName":"headerImage6","tileColor":"apps-darkblue"}}' "$FUSION_API/apps" > /dev/null

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"
