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

echo "Creating the ml20news collection in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"ml20news","solrParams":{"replicationFactor":1,"numShards":2,"maxShardsPerNode":2},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

# Stage to extract the newsgroup label
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @fusion-ml20news-index-pipeline.json "$FUSION_API/index-pipelines/ml20news-default"
curl -u $FUSION_USER:$FUSION_PASS -X PUT "$FUSION_API/index-pipelines/ml20news-default/refresh"

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"body_t", "type":"text_en", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"subject", "type":"text_en", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/ml20news/schema?updateTimeoutSecs=20"

# enable soft-commits
curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' "http://$FUSION_SOLR/solr/ml20news/config"

# Download and index the newsgroups data
THIS_LAB_DIR=`dirname "$SETUP_SCRIPT"`
THIS_LAB_DIR=`cd "$THIS_LAB_DIR"; pwd`
DATA_NAME=20news-18828
DATA_DIR=$THIS_LAB_DIR/$DATA_NAME
DATA_URL="http://qwone.com/~jason/20Newsgroups/20news-18828.tar.gz"

DOWNLOAD_DATA=true
if [ -d "$DATA_DIR" ]; then
    if [ "$(ls -A $DATA_DIR)" ]; then
        echo -e "\nFound existing $DATA_NAME data in $DATA_DIR"
        DOWNLOAD_DATA=false
    else
        echo "Empty $DATA_DIR"
        rm -f $DATA_DIR
    fi
fi

if [ "$DOWNLOAD_DATA" = true ]; then
  echo -e "\n$DATA_DIR directory not found ... \n   ... Downloading $DATA_NAME dataset from: $DATA_URL"
  curl -O $DATA_URL
  tar zxf 20news-18828.tar.gz
  if [ -f "$DATA_DIR/talk.religion.misc/84570" ]; then
    echo -e "\nSuccessfully downloaded $DATA_NAME data to $DATA_DIR"
  else
    echo -e "\nDownload / extract of 20news-18828.tar.gz failed! Please download $DATA_URL manually and extract to $THIS_LAB_DIR"
  fi
  rm 20news-18828.tar.gz
fi

# Setup a local FS crawl in Fusion to index the newsgroups data
cp fusion-ml20news-file-crawler-config.tmpl fusion-ml20news-file-crawler-config.json
sed -i.bak 's|DATA_DIR|'$DATA_DIR'|g' fusion-ml20news-file-crawler-config.json
curl -u $FUSION_USER:$FUSION_PASS -X POST --data-binary @fusion-ml20news-file-crawler-config.json -H "Content-type: application/json" "$FUSION_API/connectors/datasources"

# Kick-off the crawler
echo -e "\nStarting the crawl-local-20news-18828-dir job to index data in $DATA_DIR"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type: application/json" "$FUSION_API/connectors/jobs/crawl-local-20news-18828-dir"

# Poll the job status until it is done ...
echo -e "\nWill poll the crawl-local-20news-18828-dir job status for up to 3 minutes to wait for indexing to complete."
export PYTHONIOENCODING=utf8
sleep 10
COUNTER=0
MAX_LOOPS=36
job_status="RUNNING"
while [  $COUNTER -lt $MAX_LOOPS ]; do
  job_status=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/connectors/jobs/crawl-local-20news-18828-dir" | python -c "import sys, json; print(json.load(sys.stdin)['state'])")
  echo "The crawl-local-20news-18828-dir job is: $job_status"
  if [ "RUNNING" == "$job_status" ]; then
    sleep 10
    let COUNTER=COUNTER+1  
  else
    let COUNTER=999
  fi
done

if [ "$job_status" != "FINISHED" ]; then
  echo -e "\nThe crawl-local-20news-18828-dir job has not finished (last known state: $job_status) in over 3 minutes! Script will exit as there's likely a problem that needs to be corrected manually."
  exit 1
fi

num_found=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/api/apollo/solr/ml20news/select?q=*:*&rows=0&wt=json&echoParams=none" | python -c "import sys, json; print(json.load(sys.stdin)['response']['numFound'])")
echo -e "\nIndexing newsgroup documents completed. Found $num_found"

echo -e "\nCreating model config in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type: application/json" --data-binary @ml20news_spark_job.json "$FUSION_API/apps/bootcamp/spark/configurations"

echo -e "\nRunning job in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:ml20news/actions" -d '{"action":"start","comment":"Started via bash script"}' -H "Content-type: application/json"

# Poll the job status until it is done ...
echo -e "\nWill poll the ml20news job status for up to 3 minutes to wait for training to complete."
export PYTHONIOENCODING=utf8
sleep 10
COUNTER=0
MAX_LOOPS=36
job_status="running"
while [  $COUNTER -lt $MAX_LOOPS ]; do
  job_status=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/spark/jobs/ml20news" | python -c "import sys, json; print(json.load(sys.stdin)['state'])")
  echo "The ml20news job is: $job_status"
  if [ "running" == "$job_status" ] || [ "starting" == "$job_status" ]; then
    sleep 10
    let COUNTER=COUNTER+1
  else
    let COUNTER=999
  fi
done

echo -e "\n Model built into Fusion. Setting up index pipeline"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @fusion-ml20news-index-pipeline-ml.json $FUSION_API/index-pipelines/ml20news-default
curl -u $FUSION_USER:$FUSION_PASS -X PUT  $FUSION_API/index-pipelines/ml20news-default/refresh

echo -e "\nTesting the ML model with sample documents:"

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"1",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "body_t", "value": "this is a doc about atheism and atheists" }
    ]
  }
]' "$FUSION_API/index-pipelines/ml20news-default/collections/ml20news/index?echo=true"

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"2",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "body_t", "value": "this is a doc about a game that involves pitching, catching, and homeruns" }
    ]
  }
]' "$FUSION_API/index-pipelines/ml20news-default/collections/ml20news/index?echo=true"

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"3",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "body_t", "value": "this is a doc about windscreens and face shields for cycles" }
    ]
  }
]' "$FUSION_API/index-pipelines/ml20news-default/collections/ml20news/index?echo=true"

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/vnd.lucidworks-document" -d '[
  {
    "id":"4",
    "fields": [
      { "name": "ts", "value": "2016-02-24T00:10:01Z" },
      { "name": "subject", "value": "motorcycles" },
      { "name": "body_t", "value": "this is a doc about windscreens and face shields for cycles" }
    ]
  }
]' "$FUSION_API/index-pipelines/ml20news-default/collections/ml20news/index?echo=true"

