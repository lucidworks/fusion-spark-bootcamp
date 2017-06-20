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

echo -e "\n\nRecommendations for user: 2097"
curl -u $FUSION_USER:$FUSION_PASS -XGET "$FUSION_API/query-pipelines/music_rec_demo_items_for_user_recommendations/collections/music_rec_demo/select?q=*:*&user_id=2097&wt=json"

echo -e "\n\nRecommendations for item: Johnny Cash-Solitary Man"
curl -u $FUSION_USER:$FUSION_PASS -XGET "$FUSION_API/query-pipelines/music_rec_demo_items_for_item_recommendations/collections/music_rec_demo/select?q=*:*&item_id=Johnny%20Cash-Solitary%20Man&wt=json"

echo -e "\n\n"
