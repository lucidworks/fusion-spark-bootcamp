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

COLLECTION=sparknlp_ner_demo

echo -e "\nCreating new Fusion collection $COLLECTION in the $BOOTCAMP app ..."
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" -d '{"id":"sparknlp_ner_extraction","solrParams":{"replicationFactor":1,"numShards":4,"maxShardsPerNode":4},"type":"DATA"}' \
  "$FUSION_API/apps/$BOOTCAMP/collections"

echo -e "\nCreating Spark job for Spark-nlp NER extraction bootcamp lab"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @process_ner_job.json \
    "$FUSION_API/apps/$BOOTCAMP/spark/configurations"

echo -e "\n Spark job was created. Please login to Fusion, navigate to the bootcamp app, and the 'sparknlp_ner_extraction' job to start this job"