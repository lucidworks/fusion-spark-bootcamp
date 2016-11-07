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

COLLECTION=nyc_taxi

echo -e "\nCreating new Fusion collection: $COLLECTION"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" \
  -d '{"solrParams":{"replicationFactor":1,"numShards":6,"maxShardsPerNode":6},"type":"DATA"}' \
  $FUSION_API/collections/$COLLECTION

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": [
    { "name":"cab_type_id", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"vendor_id", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"pickup_datetime", "type":"tdate", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"dropoff_datetime", "type":"tdate", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"store_and_fwd_flag", "type":"string", "stored":true, "indexed":true, "multiValued":false },
    { "name":"rate_code_id", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"pickup", "type":"location", "stored":true, "indexed":true, "multiValued":false, "docValues":false },
    { "name":"dropoff", "type":"location", "stored":true, "indexed":true, "multiValued":false, "docValues":false },
    { "name":"passenger_count", "type":"tint", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"trip_distance", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"fare_amount", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"extra", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"mta_tax", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"tip_amount", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"tolls_amount", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"ehail_fee", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"improvement_surcharge", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"total_amount", "type":"tdouble", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"payment_type", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"trip_type", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"pickup_nyct2010_gid", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true },
    { "name":"dropoff_nyct2010_gid", "type":"string", "stored":true, "indexed":true, "multiValued":false, "docValues":true }
  ]
}' "http://$FUSION_SOLR/solr/$COLLECTION/schema?updateTimeoutSecs=20"

echo -e "\nEnabling auto-soft-commits for every 10 seconds"
curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":10000 }
}' http://$FUSION_SOLR/solr/$COLLECTION/config

echo -e "\nCreating catalog objects"
curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/nyctaxi"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @nyctaxi.json \
  "$FUSION_API/catalog"

curl -u $FUSION_USER:$FUSION_PASS -XDELETE "$FUSION_API/catalog/nyctaxi/assets/ratings"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @nyctaxi_trips.json \
  "$FUSION_API/catalog/nyctaxi/assets"

echo -e "\n\nSetup complete. Check the Fusion logs for more info."
