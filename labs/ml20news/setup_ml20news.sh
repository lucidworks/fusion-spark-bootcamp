#!/bin/bash

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

COLL=ml20news
echo "Creating the $COLL collection in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":2,"maxShardsPerNode":2},"type":"DATA"}' $FUSION_API/collections/$COLL

# Stage to extract the newsgroup label
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @fusion-ml-20news-pipeline.json $FUSION_API/index-pipelines/$COLL-default
curl -u $FUSION_USER:$FUSION_PASS -X PUT  $FUSION_API/index-pipelines/$COLL-default/refresh

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"content_txt", "type":"text_en", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"subject", "type":"text_en", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/$COLL/schema?updateTimeoutSecs=20"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/zip" --data-binary @ml-pipeline-model.zip "$FUSION_API/blobs/ml20news?modelType=com.lucidworks.spark.ml.SparkMLTransformerModel"
curl -u $FUSION_USER:$FUSION_PASS -X PUT  $FUSION_API/index-pipelines/$COLL-default/refresh

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"1",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "content_txt", "value": "this is a doc about atheism and atheists" }
    ]
  }
]' $FUSION_API/index-pipelines/$COLL-default/collections/$COLL/index

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"2",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "content_txt", "value": "this is a doc about a game that involves pitching, catching, and homeruns" }
    ]
  }
]' $FUSION_API/index-pipelines/$COLL-default/collections/$COLL/index

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"3",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "content_txt", "value": "this is a doc about windscreens and face shields for cycles" }
    ]
  }
]' $FUSION_API/index-pipelines/$COLL-default/collections/$COLL/index

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"4",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "subject", "value": "motorcycles" },
      { "name": "content_txt", "value": "this is a doc about windscreens and face shields for cycles" }
    ]
  }
]' $FUSION_API/index-pipelines/$COLL-default/collections/$COLL/index

