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

# find data assets about movies
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/_search?keyword=taxi"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"select * from nyctaxi"
}' "$FUSION_API/catalog/nyctaxi/query"

# explore the trips table

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/cab_type_id"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/pickup_datetime"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/dropoff_datetime"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/trip_duration_secs"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/rate_code_id"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/passenger_count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/trip_distance"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/fare_amount"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/extra"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/mta_tax"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/tip_amount"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/tolls_amount"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/total_amount"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/payment_type"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/pickup?facet.heatmap.geom=%5B%22-73.9599+40.693%22+TO+%22-73.037+40.913%22%5d&facet.heatmap.gridLevel=5"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/nyctaxi/assets/trips/columns/dropoff"
