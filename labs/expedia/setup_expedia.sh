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

TEST=expedia_test
TRAIN=expedia_train
DESTINATIONS=expedia_destinations

# Create expedia_test
echo -e "\nCreating new Fusion collection: $TEST"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" \
  -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/$TEST

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/$TEST/config

# Create expedia_train
echo -e "\nCreating new Fusion collection: $TRAIN"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" \
  -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/$TRAIN

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/$TRAIN/config

# Create expedia_destinations
echo -e "\nCreating new Fusion collection: $DESTINATIONS"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" \
  -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/$DESTINATIONS

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/$DESTINATIONS/config

# Create Catalog expedia project
echo -e "\nCreating catalog objects"
curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/expedia"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @expedia.json \
  "$FUSION_API/catalog"

# Create test asset
curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/expedia/assets/test"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @expedia_test.json \
  "$FUSION_API/catalog/expedia/assets"
  
# Create train asset
curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/expedia/assets/train"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @expedia_train.json \
  "$FUSION_API/catalog/expedia/assets"

# Create destinations asset
curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/expedia/assets/destinations"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @expedia_destinations.json \
  "$FUSION_API/catalog/expedia/assets"

echo -e "\n\nSetup complete. Check the Fusion logs for more info."
