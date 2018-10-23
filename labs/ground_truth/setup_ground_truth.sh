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

COLLECTION="groundtruth_demo"
APP_URL="$FUSION_API/apps/$COLLECTION"
PRODUCTS_SPARK_JOB_ID="load_products_spark"
SIGNALS_SPARK_JOB_ID="load_signals_spark"
EXPERIMENT="groundtruth_demo-exp"
GROUND_TRUTH_SPARK_JOB_ID="${EXPERIMENT}-groundTruth-bb-relevance"
RANKING_METRICS_SPARK_JOB_ID="${EXPERIMENT}-rankingMetrics-bb-relevance"

curl -s -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d '{"id":"groundtruth_demo", "name":"groundtruth_demo","description":"dev","properties":{"headerImageName":"headerImage6","tileColor":"apps-darkblue"}}' "$FUSION_API/apps"
echo -e "\nCreated new Fusion app: $COLLECTION"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/apps/$COLLECTION"

# Create Spark job configurations
echo "Creating Spark job for loading products"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @load_products_spark_job.json \
  "$APP_URL/spark/configurations"

echo "Creating Spark job for loading signals"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @load_signals_spark_job.json \
  "$APP_URL/spark/configurations"

# Run Spark jobs for loading data
echo "Running Spark job ${PRODUCTS_SPARK_JOB_ID}"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:$PRODUCTS_SPARK_JOB_ID/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status $PRODUCTS_SPARK_JOB_ID

echo "Running Spark job ${SIGNALS_SPARK_JOB_ID}"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:$SIGNALS_SPARK_JOB_ID/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status $SIGNALS_SPARK_JOB_ID

# Run aggregation explicitly
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:${COLLECTION}_click_signals_aggregation/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status ${COLLECTION}_click_signals_aggregation

# Create pipelines
echo "Creating pipeline with no recs"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @query_pipeline_norecs.json \
  "$APP_URL/query-pipelines"

# Create an experiment and activate it
echo "Creating an experiment"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @experiment.json \
  "$APP_URL/experiments"

echo "Activating experiment"
curl -u $FUSION_USER:$FUSION_PASS -X POST -H "Content-type:application/json" --data-binary @experiment.json \
  "$APP_URL/experiments/${EXPERIMENT}/job"

# Run ground truth, ranking metric jobs
echo "Running Ground Truth Spark job"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:${GROUND_TRUTH_SPARK_JOB_ID}/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status ${GROUND_TRUTH_SPARK_JOB_ID}

echo "Running Ranking metrics Spark job"
curl -u $FUSION_USER:$FUSION_PASS -X POST "$FUSION_API/jobs/spark:${RANKING_METRICS_SPARK_JOB_ID}/actions" -H "Content-type: application/json" \
  -d '{"action": "start", "comment": "Started by script"}'
poll_job_status ${RANKING_METRICS_SPARK_JOB_ID}

echo "Stop experiment"
curl -u $FUSION_USER:$FUSION_PASS -X DELETE -H "Content-type:application/json" "$APP_URL/experiments/${EXPERIMENT}/job"
