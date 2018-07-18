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
  --data-binary '{"name":"timestamp_tdt","type":"tdate","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
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
  --data-binary '{"name":"itemInSession","type":"tint","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"method","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"level","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"length","type":"tdouble","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"user_id_s","type":"string","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/collections/music_rec_demo_signals/schema/fields" \
  --data-binary '{"name":"status","type":"tint","indexed":true,"stored":true,"multiValued":false,"required":false,"dynamic":false,"docValues":true}'
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

echo -e "\n\nDone crawling events, now crawling songs ..."
cp eventsim-song-crawler.tmpl eventsim-song-crawler.json
DATA_DIR="$LABS_TIP/labs/eventsim"
sed -i.bak 's|DATA_DIR|'$DATA_DIR'|g' eventsim-song-crawler.json
# not actually running the crawlers yet....



curl -u $FUSION_USER:$FUSION_PASS -X POST --data-binary @eventsim-song-crawler.json -H "Content-type: application/json" "$FUSION_API/connectors/datasources"
echo -e "\n\nEnabling the recommendations feature for music_rec_demo ... recommender spark jobs should start automatically after this step."
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H Content-type:application/json -d '{"enabled":true}' "$FUSION_API/collections/music_rec_demo/features/recommendations"

echo -e "\nSetup complete.\n"
