#!/bin/bash

while [ -h "$SETUP_SCRIPT" ] ; do
  ls=`ls -ld "$SETUP_SCRIPT"`
  # Drop everything prior to ->
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    SETUP_SCRIPT="$link"
  else
    SETUP_SCRIPT=`dirname "$SETUP_SCRIPT"`/"$link"
  fi
done

LABS_TIP=`dirname "$SETUP_SCRIPT"`/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

CORE_SITE_XML="$FUSION_HOME/apps/spark-dist/conf/core-site.xml"
if [ ! -f "$CORE_SITE_XML" ]; then
   echo "ERROR: $CORE_SITE_XML is needed for downloading from S3"
   exit 1
fi

echo -e "\nCreating new Fusion collection: movies_ml20m"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"movies_ml20m","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

echo "Creating Spark job for loading movies from S3"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @load_movies_ml20m.json \
  "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

echo -e "\nCreating new Fusion collection: ratings_ml20m"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"ratings_ml20m","solrParams":{"replicationFactor":1,"numShards":2,"maxShardsPerNode":2},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

echo "Creating Spark job for loading ratings from S3"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @load_ratings_ml20m.json \
  "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

echo -e "\nCreating new Fusion collection: tags_ml20m"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"tags_ml20m","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

echo "Creating Spark job for loading tags from S3"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @load_tags_ml20m.json \
  "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:load_movies_ml20m/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'

curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:load_tags_ml20m/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'

curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:load_ratings_ml20m/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
