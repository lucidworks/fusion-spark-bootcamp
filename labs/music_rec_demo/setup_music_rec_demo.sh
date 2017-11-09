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

LAB_DIR=`dirname "$SETUP_SCRIPT"`
LAB_DIR=`cd "$LAB_DIR"; pwd`
LABS_TIP=$LAB_DIR/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

echo -e "\nCreating the music_rec_demo collection in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"numShards":3,"maxShardsPerNode":3}}' $FUSION_API/collections/music_rec_demo

echo -e "\n\nEnabling signals feature for music_rec_demo ..."
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H Content-type:application/json -d '{"enabled":true}' "$FUSION_API/collections/music_rec_demo/features/signals"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H Content-type:application/json -d '{"enabled":true}' "$FUSION_API/collections/music_rec_demo/features/dynamicSchema"

echo -e "\n\nCreating the song and event indexing pipelines"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d @eventsim-song-indexer.json "$FUSION_API/index-pipelines"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d @eventsim-event-indexer.json "$FUSION_API/index-pipelines"

echo -e "\n\nUpdating the schema for music_rec_demo to add song fields ..."
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo/schema/fields" \
  --data-binary '{"name":"song","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo/schema/fields" \
  --data-binary '{"name":"artist","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"timestamp_tdt","type":"pdate","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"registration","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"song","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"artist","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"auth","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"firstName","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"lastName","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"location","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"page","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"itemInSession","type":"pint","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"method","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"level","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"length","type":"pdouble","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"user_id_s","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"status","type":"pint","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"gender","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"sessionId","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"userAgent","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"doc_id_s","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'

# create the parser
echo -e "\n\nCreating a parser and datasource for the eventsim zip file ..."
curl -u $FUSION_USER:$FUSION_PASS -X POST --data-binary @eventsim-json-parser.json -H "Content-type: application/json" "$FUSION_API/parsers"

cp eventsim-event-crawler.tmpl eventsim-event-crawler.json
DATA_DIR="$LABS_TIP/labs/eventsim"
sed -i.bak 's|DATA_DIR|'$DATA_DIR'|g' eventsim-event-crawler.json
echo -e "\nUpdated DATA_DIR to $DATA_DIR"
curl -u $FUSION_USER:$FUSION_PASS -X POST --data-binary @eventsim-event-crawler.json -H "Content-type: application/json" "$FUSION_API/connectors/datasources"

echo -e "\n\nStarting the crawler job to index simulated song event data from $DATA_DIR/control.data.json.zip"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type: application/json" "$FUSION_API/connectors/jobs/eventsim-event-crawler"

# Poll the job status until it is done ...
echo -e "\n\nWill poll the crawl job status for up to 10 minutes to wait for indexing to complete."
export PYTHONIOENCODING=utf8
sleep 10
COUNTER=0
MAX_LOOPS=60
job_status="RUNNING"
while [  $COUNTER -lt $MAX_LOOPS ]; do
  job_status=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/connectors/jobs/eventsim-event-crawler" | python -c "import sys, json; print json.load(sys.stdin)['state']")
  echo "The eventsim-event-crawler job is: $job_status"
  if [ "RUNNING" == "$job_status" ]; then
    sleep 10
    let COUNTER=COUNTER+1  
  else
    let COUNTER=999
  fi
done

if [ "$job_status" != "FINISHED" ]; then
  echo -e "\nThe eventsim-event-crawler job has not finished (last known state: $job_status) in over 10 minutes! Script will exit as there's likely a problem that needs to be corrected manually.\nCheck the var/log/connectors/connectors.log in your Fusion installation for errors."
  exit 1
fi

echo -e "\n\nDone crawling events, now crawling songs ..."
cp eventsim-song-crawler.tmpl eventsim-song-crawler.json
DATA_DIR="$LABS_TIP/labs/eventsim"
sed -i.bak 's|DATA_DIR|'$DATA_DIR'|g' eventsim-song-crawler.json
curl -u $FUSION_USER:$FUSION_PASS -X POST --data-binary @eventsim-song-crawler.json -H "Content-type: application/json" "$FUSION_API/connectors/datasources"

echo -e "\n\nStarting the crawler job to index simulated song data from $DATA_DIR/control.data.json.zip"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type: application/json" "$FUSION_API/connectors/jobs/eventsim-song-crawler"

# Poll the job status until it is done ...
echo -e "\n\nWill poll the crawl job status for up to 10 minutes to wait for indexing to complete."
export PYTHONIOENCODING=utf8
sleep 10
COUNTER=0
MAX_LOOPS=60
job_status="RUNNING"
while [  $COUNTER -lt $MAX_LOOPS ]; do
  job_status=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/connectors/jobs/eventsim-song-crawler" | python -c "import sys, json; print json.load(sys.stdin)['state']")
  echo "The eventsim-song-crawler job is: $job_status"
  if [ "RUNNING" == "$job_status" ]; then
    sleep 10
    let COUNTER=COUNTER+1
  else
    let COUNTER=999
  fi
done

if [ "$job_status" != "FINISHED" ]; then
  echo -e "\nThe eventsim-song-crawler job has not finished (last known state: $job_status) in over 10 minutes! Script will exit as there's likely a problem that needs to be corrected manually.\nCheck the var/log/connectors/connectors.log in your Fusion installation for errors."
  exit 1
fi

echo -e "\n\nEnabling the recommendations feature for music_rec_demo ... recommender spark jobs should start automatically after this step."
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H Content-type:application/json -d '{"enabled":true}' "$FUSION_API/collections/music_rec_demo/features/recommendations"

echo -e "\nSetup complete.\n"
