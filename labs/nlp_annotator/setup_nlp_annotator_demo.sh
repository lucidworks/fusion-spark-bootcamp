#!/bin/bash

SCRIPT_HOME="$(dirname "${BASH_SOURCE-$0}")"
LABS_TIP=${SCRIPT_HOME}/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`


echo -n "Where is Fusion installed (please include the version number e.g. /my/fusion/4.1.0):"
read fusion_home
SED_PATTERN="s|<FUSION_HOME>|$fusion_home|g"
sed -i.bak "$SED_PATTERN" myenv.sh

# check if Fusion is running
cd $fusion_home
echo "Checking Fusion server status..."
zk_status="$(./bin/zookeeper status)"
echo $zk_status
solr_status="$(./bin/solr status)"
echo $solr_status
api_status="$(./bin/api status)"
echo $api_status
cc_status="$(./bin/connectors-classic status)"
echo $cc_status
proxy_status="$(./bin/proxy status)"
echo $proxy_status
webapp_status="$(./bin/webapps status)"
echo $webapp_status
adui_status="$(./bin/admin-ui status)"
echo $adui_status
if [[ $zk_status == *"zookeeper is running"* ]] && [[ $solr_status == *"solr is running"* ]] && [[ $api_status == *"api is running"* ]] && [[ $cc_status == *"connectors-classic is running"* ]] && [[ $proxy_status == *"proxy is running"* ]] && [[ $webapp_status == *"webapps is running"* ]] && [[ $adui_status == *"admin-ui is running"* ]];
then
    echo "Fusion is running ok, continue..."
else
    echo "Fusion is not running properly, please check. Abort..."
    exit 0
fi
cd -

source "myenv.sh"
check_for_core_site
cd ${SCRIPT_HOME}

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

COLLECTION=nlp_annotator_demo
INDEX_PIPELINE=nlp_annotation_extraction
JOB_ID=nlp_annotation_extraction


echo -e "\nCreating new Fusion collection $COLLECTION in the $BOOTCAMP app ..."
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"nlp_annotator_demo","solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections?defaultFeatures=false"


echo -e "\nCreating Spark job for NLP annotation extraction bootcamp lab"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @ner_extraction_job.json \
    "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d @insure_index_pipeline.json $FUSION_API/apps/$BOOTCAMP/index-pipelines/$INDEX_PIPELINE
curl -u $FUSION_USER:$FUSION_PASS -X PUT  $FUSION_API/apps/$BOOTCAMP/index-pipelines/$INDEX_PIPELINE/refresh

echo -e "\n Spark job created"

# Run Spark jobs for loading data
echo "Running Spark job ${JOB_ID}"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:$JOB_ID/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status $JOB_ID
