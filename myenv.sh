#!/bin/bash

FUSION_HOME=
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

curl -X POST -H 'Content-type: application/json' -d '{"password":"password123"}' http://$FUSION/api

# create bootcamp app if needed
export BOOTCAMP=bootcamp
APP_EXISTS=$(curl -s -u $FUSION_USER:$FUSION_PASS -o /dev/null -w '%{http_code}' "$FUSION_API/apps/bootcamp")
if [ $APP_EXISTS -eq 404 ]; then
  echo -e "\nbootcamp app not found, creating ..."
  curl -s -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d '{"id":"bootcamp", "name":"bootcamp","description":"dev","properties":{"headerImageName":"headerImage6","tileColor":"apps-darkblue"}}' "$FUSION_API/apps?relatedObjects=false"
  echo -e "\nCreated new Fusion app: bootcamp"
  curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/apps/bootcamp"
fi

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"
