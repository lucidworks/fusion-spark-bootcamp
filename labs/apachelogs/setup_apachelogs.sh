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

COLLECTION=apachelogs

echo -e "\nCreating new Fusion collection $COLLECTION in the $BOOTCAMP app ..."
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"apachelogs","solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections"
sleep 5
# ugh! going thru the proxy doesn't seem to work!!!
curl -X POST -H "Content-type:application/json" --data-binary '{
  "add-field": { "name":"clientip", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"ts", "type":"pdate", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"verb", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"response", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"timestamp", "type":"string", "stored":true, "indexed":true, "multiValued":false },
  "add-field": { "name":"bytes", "type":"pint", "stored":true, "indexed":true, "multiValued":false }
}' "http://$FUSION_SOLR/solr/$COLLECTION/schema?updateTimeoutSecs=20"

echo -e "\n\nUpdating the apachelogs pipeline"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type: application/json" --data-binary @pipeline.json \
  $FUSION_API/index-pipelines/apachelogs

echo -e "\n\nIndexing sample apache logs into $COLLECTION"
FUSION_PIPELINE=$FUSION_API/index-pipelines/apachelogs/collections/$COLLECTION/index
java -jar fusion-log-indexer-1.0-exe.jar -dir logs_sample \
  -fusion $FUSION_PIPELINE -fusionUser $FUSION_USER -fusionPass $FUSION_PASS -senderThreads 6 -fusionBatchSize 1000 \
  -lineParserConfig apachelogs-grok-parser.properties

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/apachelogs_signals_aggr/config

curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-Type: application/json" --data-binary @job.json "$FUSION_API/apps/$BOOTCAMP/spark/configurations"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-Type: application/json" "$FUSION_API/spark/jobs/sessionize?sync=true"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/spark/jobs"

echo -e "\nChecking results of job in apachelogs_signals_aggr ..."
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/query-pipelines/_system/collections/apachelogs_signals_aggr/select?q=clientip:%5B%2A+TO+%2A%5D&wt=json&rows=0"

echo -e "\n\nJob complete. Check the Fusion logs for more info."

