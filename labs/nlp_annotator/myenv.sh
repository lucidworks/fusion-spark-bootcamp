#!/bin/bash

FUSION_HOME=<FUSION_HOME>
FUSION="localhost:8764"
FUSION_USER=admin
FUSION_PASS=password123
FUSION_SOLR="localhost:8983"
FUSION_API="http://$FUSION/api/apollo"

curl -X POST -H 'Content-type: application/json' -d '{"password":"password123"}' http://$FUSION/api

# create bootcamp app if needed
export BOOTCAMP=bootcamp
APP_EXISTS=$(curl -s -u $FUSION_USER:$FUSION_PASS -o /dev/null -w '%{http_code}' "$FUSION_API/apps/bootcamp")
if [ $APP_EXISTS -eq 404 ]; then
  echo -e "\nbootcamp app not found, creating ..."
  curl -s -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" -d '{"id":"bootcamp", "name":"bootcamp","description":"dev","properties":{"headerImageName":"headerImage6","tileColor":"apps-darkblue"}}' "$FUSION_API/apps?relatedObjects=false"
  echo -e "\nCreated new Fusion app: bootcamp"
  curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/apps/bootcamp"
fi

echo -e "\nConfigured to connect to Fusion API service at $FUSION_API as user $FUSION_USER"

check_for_core_site() {
  CORE_SITE_XML="$FUSION_HOME/apps/spark-dist/conf/core-site.xml"
  if [ ! -f "$CORE_SITE_XML" ]; then
    if [ ! -f "$LABS_TIP/core-site.xml" ]; then
       echo "ERROR: "$LABS_TIP/core-site.xml" does not exist. Copy "$LABS_TIP/core-site.xml.template" to "$LABS_TIP/core-site.xml" and fill in AWS creds"
       exit 1
    else
       echo "Copying $LABS_TIP/core-site.xml to $FUSION_HOME/apps/spark-dist/conf"
       cp "$LABS_TIP/core-site.xml" "$FUSION_HOME/apps/spark-dist/conf"
    fi
  fi
}

# Poll the job status until it is done ...
poll_job_status () {
    if [ -z "$1" ]                           # Is parameter #1 zero length?
    then
      echo "Job ID not passed to function for status check"  # Or no parameter passed.
      exit 1
    fi
    JOB_ID=$1

    echo -e "\nWill poll the $job_id job status for up to 6 minutes to wait for training to complete."
    export PYTHONIOENCODING=utf8
    sleep 10
    COUNTER=0
    MAX_LOOPS=36
    JOB_STATUS=""
    while [  $COUNTER -lt $MAX_LOOPS ]; do
      JOB_STATUS=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/spark/jobs/$JOB_ID" | python -c "import sys, json; print(json.load(sys.stdin)['state'])")
      echo "Job status for $JOB_ID is: ${JOB_STATUS}"
      if [ "running" == ${JOB_STATUS} ] || [ "starting" == ${JOB_STATUS} ]; then
        sleep 10
        let COUNTER=COUNTER+1
      else
        let COUNTER=999
      fi
    done
    if [ "finished" != ${JOB_STATUS} ]; then
      JOB_STATUS_RESP=$(curl -u $FUSION_USER:$FUSION_PASS -s "$FUSION_API/spark/jobs/$JOB_ID")
      echo "Job ${JOB_ID} failed with status ${JOB_STATUS_RESP}. Exiting setup script"
      exit 1
    fi
}
