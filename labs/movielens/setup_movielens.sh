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

COLLECTION=movielens

# Download the movielens dataset
THIS_LAB_DIR=`dirname "$SETUP_SCRIPT"`
THIS_LAB_DIR=`cd "$THIS_LAB_DIR"; pwd`
DATA_DIR=$THIS_LAB_DIR/ml-100k
DATA_URL="http://files.grouplens.org/datasets/movielens/ml-100k.zip"
if [ -d "$DATA_DIR" ]; then
  echo -e "\nFound existing ml-100k data in $DATA_DIR"
else
  echo -e "\n$DATA_DIR directory not found ... downloading movielens ml-100k dataset from: $DATA_URL"
  curl -O $DATA_URL
  unzip ml-100k.zip
  if [ -f "$DATA_DIR/u.item" ]; then
    cp omdb_movies.json $DATA_DIR/
    cp us_postal_codes.csv $DATA_DIR/
    echo -e "\nSuccessfully downloaded ml-100k data to $DATA_DIR"
  else
    echo -e "\nDownload / extract of ml-100k.zip failed! Please download $DATA_URL manually and extract to $THIS_LAB_DIR"
  fi
  rm ml-100k.zip
fi

echo -e "\nCreating new Fusion collection: $COLLECTION"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/$COLLECTION

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/$COLLECTION/config

echo -e "\nCreating new Fusion collection: movielens_users"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/movielens_users

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/movielens_users/config

echo -e "\nCreating new Fusion collection: movielens_movies"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/movielens_movies

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/movielens_movies/config

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"title_txt_en", "type":"text_en", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/movielens_movies/schema?updateTimeoutSecs=20"

echo -e "\nCreating new Fusion collection: movielens_ratings"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/movielens_ratings

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/movielens_ratings/config

echo -e "\nCreating new Fusion collection: us_zipcodes"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/us_zipcodes

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/us_zipcodes/config

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"geo_location", "type":"location", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"geo_location_rpt", "type":"location_rpt", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/us_zipcodes/schema?updateTimeoutSecs=20"

echo -e "\nCreating catalog objects"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @movielens.json \
  "$FUSION_API/catalog"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @movielens_ratings.json \
  "$FUSION_API/catalog/movielens/assets"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @movielens_users.json \
  "$FUSION_API/catalog/movielens/assets"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @movielens_movies.json \
  "$FUSION_API/catalog/movielens/assets"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/movielens/assets"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @geo.json \
  "$FUSION_API/catalog"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @us_zipcodes.json \
  "$FUSION_API/catalog/geo/assets"

echo -e "\nLoading movielens data into Solr using Fusion's spark-shell wrapper at: $FUSION_HOME/bin/spark-shell\n"
$FUSION_HOME/bin/spark-shell --packages com.databricks:spark-csv_2.10:1.5.0 -i load_solr.scala

echo -e "\n\nSetup complete. Check the Fusion logs for more info."
