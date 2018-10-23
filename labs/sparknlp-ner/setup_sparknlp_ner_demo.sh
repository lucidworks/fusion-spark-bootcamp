#!/bin/bash

SCRIPT_HOME="$(dirname "${BASH_SOURCE-$0}")"
LABS_TIP=${SCRIPT_HOME}/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"
check_for_core_site
cd ${SCRIPT_HOME}

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

COLLECTION=sparknlp_ner_demo
JOB_ID=sparknlp_ner_extraction

echo -e "\nCreating new Fusion collection $COLLECTION in the $BOOTCAMP app ..."
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"sparknlp_ner_extraction","solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"

curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"location", "type":"string", "stored":true, "indexed":true, "multiValued":true },
  "add-field": { "name":"person", "type":"string", "stored":true, "indexed":true, "multiValued":true },
  "add-field": { "name":"misc", "type":"string", "stored":true, "indexed":true, "multiValued":true },
  "add-field": { "name":"organization", "type":"string", "stored":true, "indexed":true, "multiValued":true }
}' "http://$FUSION_SOLR/solr/sparknlp_ner_extraction/schema?updateTimeoutSecs=20"

echo -e "\nCreating Spark job for Spark-nlp NER extraction bootcamp lab"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @process_ner_job.json \
    "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @sparknlp_ner_extraction-pipeline.json $FUSION_API/apps/$BOOTCAMP/index-pipelines/sparknlp_ner_extraction
curl -u $FUSION_USER:$FUSION_PASS -X PUT  $FUSION_API/apps/$BOOTCAMP/index-pipelines/sparknlp_ner_extraction/refresh

echo -e "\n Spark job created"

# Run Spark jobs for loading data
echo "Running Spark job ${JOB_ID}"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:$JOB_ID/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status $JOB_ID
