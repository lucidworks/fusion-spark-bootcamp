#!/bin/bash
set -e

SCRIPT_HOME="$(dirname "${BASH_SOURCE-$0}")"
LABS_TIP=${SCRIPT_HOME}/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"
cd ${SCRIPT_HOME}

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

# Download the movielens dataset

# verify unzip is installed otherwise the script breaks in a weird state
if ! hash unzip 2>/dev/null ; then
  echo -e "\nunzip must be installed to run this setup script! Please install unzip utility and re-run."
  exit 1
fi

THIS_LAB_DIR=`dirname "$SETUP_SCRIPT"`
THIS_LAB_DIR=`cd "$THIS_LAB_DIR"; pwd`
DATA_DIR=$THIS_LAB_DIR/ml-100k
DATA_URL="http://files.grouplens.org/datasets/movielens/ml-100k.zip"
if [ -d "$DATA_DIR" ]; then
    cp omdb_movies.json $DATA_DIR/
    cp us_postal_codes.csv $DATA_DIR/
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

echo -e "\nCreating new Fusion collection: users"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"users","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/users/config

echo -e "\nCreating new Fusion collection: movies"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"movies","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/movies/config

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"title_txt_en", "type":"text_en", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/movies/schema?updateTimeoutSecs=20"

echo -e "\nCreating new Fusion collection: ratings"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"ratings","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/ratings/config

echo -e "\nCreating new Fusion collection: zipcodes"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"zipcodes","solrParams":{"replicationFactor":1,"numShards":1},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/zipcodes/config

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"geo_location", "type":"location", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"geo_location_rpt", "type":"location_rpt", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/zipcodes/schema?updateTimeoutSecs=20"

echo -e "\nLoading movielens data into Solr using Fusion's spark-shell wrapper at: $FUSION_HOME/bin/spark-shell\n"
echo "dataDir=$DATA_DIR" > load_solr.properties
$FUSION_HOME/bin/spark-shell -M local[*] --setup-props $THIS_LAB_DIR/load_solr.properties -i load_solr.scala

echo -e "\nStarting the SQL engine"
curl -u $FUSION_USER:$FUSION_PASS -H 'Content-type:application/json' -X PUT -d '4' "$FUSION_API/configurations/fusion.sql.cores"
curl -u $FUSION_USER:$FUSION_PASS -H 'Content-type:application/json' -X PUT -d '4' "$FUSION_API/configurations/fusion.sql.executor.cores"
curl -u $FUSION_USER:$FUSION_PASS -H 'Content-type:application/json' -X PUT -d '2g' "$FUSION_API/configurations/fusion.sql.memory"
curl -u $FUSION_USER:$FUSION_PASS -H 'Content-type:application/json' -X PUT -d '8' "$FUSION_API/configurations/fusion.sql.default.shuffle.partitions"

$FUSION_HOME/bin/sql restart
$FUSION_HOME/bin/sql status

echo -e "\n\nSetup complete. Check the Fusion logs for more info."
