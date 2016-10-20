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

COLL=eventsim

if [ "$SPARK_SOLR_HOME" == ""  ]; then
  echo -e "Please clone the spark-solr project from github and set the SPARK_SOLR_HOME variable in myenv.sh before running this script."
  exit 1
fi

SPARK_SOLR_JAR=$(find $SPARK_SOLR_HOME/target -name "spark-solr-*-shaded.jar")
echo -e "SPARK_SOLR_JAR= $SPARK_SOLR_JAR"

if [ ! -f "$SPARK_SOLR_JAR" ]; then
  echo -e "ERROR: Please build the spark-solr JAR using maven before running this script."
  exit 1
fi

echo -e "\nCreating the $COLL collection in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H "Content-type:application/json" -d '{"solrParams":{"numShards":3,"maxShardsPerNode":3}}' $FUSION_API/collections/$COLL

curl -XPOST -H "Content-type:application/json" -d '{
  "set-property": { "updateHandler.autoSoftCommit.maxTime":5000 }
}' http://$FUSION_SOLR/solr/eventsim/config

echo -e "\nEnabling the partitionByTime feature in Fusion"
curl -u $FUSION_USER:$FUSION_PASS -X PUT -H 'Content-type: application/json' -d '{ "enabled":true, "timestampFieldName":"ts", "timePeriod":"1DAYS", "scheduleIntervalMinutes":1, "preemptiveCreateEnabled":false, "maxActivePartitions":100, "deleteExpired":false }' $FUSION_API/collections/$COLL/features/partitionByTime

EVENTSIM_DATA="$LAB_DIR/control.data.json"

echo -e "EVENTSIM_DATA=$EVENTSIM_DATA"

if [ ! -f "$EVENTSIM_DATA" ]; then
  echo -e "\nExtracting sample data ..."
  unzip -a control.data.json.zip
fi

SPARK_MASTER=$(curl -s -u $FUSION_USER:$FUSION_PASS "$FUSION_API/spark/master")
SOLR_ZKHOST=$(curl -s -u $FUSION_USER:$FUSION_PASS "$FUSION_API/configurations/com.lucidworks.apollo.solr.zk.connect")

echo -e "\nLaunching eventsim example using Spark master $SPARK_MASTER and Solr ZK host $SOLR_ZKHOST\n"

$FUSION_HOME/apps/spark-dist/bin/spark-submit --master $SPARK_MASTER --class com.lucidworks.spark.SparkApp $SPARK_SOLR_JAR eventsim \
   --zkHost $SOLR_ZKHOST --collection $COLL --eventsimJson "$EVENTSIM_DATA" --fusionUser $FUSION_USER --fusionPass $FUSION_PASS \
  --fusion "$FUSION_API/index-pipelines/$COLL-default/collections/$COLL/index" -fusionAuthEnabled true
