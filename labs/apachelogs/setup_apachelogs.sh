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

COLLECTION=apachelogs

echo -e "\nCreating new Fusion collection: $COLLECTION"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  $FUSION_API/collections/$COLLECTION

echo -e "\n\nEnabling signals feature for collection $COLLECTION"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"enabled":true}' \
  $FUSION_API/collections/$COLLECTION/features/signals

echo -e "\n\nUpdating the Solr schema"
#curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary '{
#  "add-field": { "name":"clientip", "type":"string", "stored":true, "indexed":true, "multiValued":false },
#  "add-field": { "name":"ts", "type":"pdate", "stored":true, "indexed":true, "multiValued":false },
#  "add-field": { "name":"verb", "type":"string", "stored":true, "indexed":true, "multiValued":false },
#  "add-field": { "name":"response", "type":"string", "stored":true, "indexed":true, "multiValued":false },
#  "add-field": { "name":"timestamp", "type":"string", "stored":true, "indexed":true, "multiValued":false },
#  "add-field": { "name":"bytes", "type":"pint", "stored":true, "indexed":true, "multiValued":false }
#}' "$FUSION_API/solr/$COLLECTION/schema?updateTimeoutSecs=20"

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

curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-Type: application/json" --data-binary @job.json "$FUSION_API/spark/configurations/sessionize"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-Type: application/json" "$FUSION_API/spark/jobs/sessionize"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/spark/jobs"

echo -e "\n\nJob complete. Check the Fusion logs for more info."

