Fusion Spark Bootcamp
========

This project contains examples and labs for learning how to use Fusion's Spark features.

* apachelogs: Run a custom script job in Scala that performs sessionization (using a SQL window function) and then computes some aggregations for each user session
* eventsim: Index simulated event data (from https://github.com/Interana/eventsim) using Fusion index pipelines and time-based partitioning
* mlsvm: Classify sentiment of tweets using SVM model trained with Spark MLlib
* ml20news: 20 newsgroup classifier based on Spark ML pipeline
* movielens: Scala script to load movielens data into Fusion
* nyc_taxi: Scala script to load NYC taxi trip data stored in Postgres into Solr using JDBC

## Setup

Download and install the latest version of Fusion 3.0.x from lucidworks.com. Take note of the location where you installed Fusion, such as `/opt/lucidworks/fusion/3.0.0`. We'll refer to this location as $FUSION_HOME hereafter.

Start Fusion by doing:
```
cd $FUSION_HOME
bin/fusion start
```

Login to the Fusion Admin UI in your browser at: http://localhost:8764

If this is the first time you're running Fusion, then you will be prompted to set a password for the default "admin" user.

Edit the `myenv.sh` script in this project to set environment specific variables used by lab setup scripts.

The default mode of Fusion 3.0.x is to run Spark in local mode, but for these labs, we recommend starting the Fusion Spark Master and Worker processes.

```
cd $FUSION_HOME
bin/spark-master start
bin/spark-worker start
```

Open the Spark Master UI at http://localhost:8767 and verify the cluster is alive and has an active worker process.

Lastly, please launch the Fusion Spark shell to verify all Fusion processes are configured and running correctly.

```
cd $FUSION_HOME
bin/spark-shell
```

## apachelogs

This lab requires Fusion 2.4.2 or later.

Run the `labs/apachelogs/setup_apachelogs.sh` script to create the Fusion objects needed to support this lab.

The setup script will index some sample log entries using the Fusion log indexer, see: [Fusion Log Indexer](https://github.com/lucidworks/fusion-log-indexer "Fusion Log Indexer")

Once indexed, the setup script registers a Scala script (`labs/apachelogs/sessionize.scala`) as a custom script job in Fusion and then runs the job. Note that the scala script has to be converted into JSON (see job.json) when submitting to Fusion.

When the job finishes, check the aggregated results in the apachelogs_signals_aggr collection. You may need to send a hard commit to make sure all records are committed to the index:

```
curl "http://localhost:8983/solr/apachelogs_signals_aggr/update?commit=true"
```

## eventsim

This lab demonstrates how to read time-partitioned data using Spark.

Run the `labs/eventsim/setup_eventsim.sh` script to create the Fusion objects needed to support this lab.

The setup script launches the Fusion spark-shell to index 180,981 sample documents (generated from the [eventsim project](https://github.com/Interana/eventsim "eventsim")).


## ml20news

This lab demonstrates how to deploy a Spark ML pipeline based classifier to predict a classification during indexing; requires Fusion 2.4.2 or later.

Run the `labs/ml20news/setup_ml20news.sh` script to create the Fusion objects needed to run this lab.

To see how the model for this lab was trained, see: [MLPipelineScala.scala](https://github.com/lucidworks/spark-solr/blob/master/src/main/scala/com/lucidworks/spark/example/ml/MLPipelineScala.scala "ML Pipeline Example")

## mlsvm 

This lab demonstrates how to deploy a Spark MLlib based classifier to predict sentiment during indexing; requires Fusion 2.4.2. or later.

Run the `labs/mlsvm/setup_mlsvm.sh` script to create the Fusion objects needed to run this lab.

To see how the model for this lab was trained, see: [SVMExample.scala](https://github.com/lucidworks/spark-solr/blob/master/src/main/scala/com/lucidworks/spark/example/ml/SVMExample.scala "MLlib example")

## movielens

This lab requires Fusion 3.0 or later.

Run the `labs/movielens/setup_movielens.sh` script to create collections in Fusion and populate them using Spark.

The setup script downloads the ml-100k data set from http://files.grouplens.org/datasets/movielens/ml-100k.zip and extracts it to `labs/movielens/ml-100k`.

You'll need unzip installed prior to running the script.

The setup script also invokes the Spark shell to load data into Solr, see the load_solr.scala script for more details.

Behind the scenes, the setup script launches the Spark shell in Fusion by doing:

```
$FUSION_HOME/bin/spark-shell --packages com.databricks:spark-csv_2.10:1.5.0 -i load_solr.scala
```
_Notice how we add the databricks csv data source package to the shell environment as it is needed by the load_solr.scala script._

After loading the data, the setup script will (re)start the Fusion SQL engine using:

```
$FUSION_HOME/bin/sql restart
```

Test the Catalog API endpoint by executing the `explore_movielens.sh` script.

_NOTE: It make take a few seconds the first time you run a query for Spark to distribute the Fusion shaded JAR to worker processes._

You can tune the resource allocation for the SQL engine so that it has a little more memory and CPU resources. Specifically, we'll give it 6 CPU cores and 2g of memory; feel free to adjust these settings for your workstation.
 
```
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d '6' "http://localhost:8764/api/apollo/configurations/fusion.sql.cores"
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d '6' "http://localhost:8764/api/apollo/configurations/fusion.sql.executor.cores"
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d '2g' "http://localhost:8764/api/apollo/configurations/fusion.sql.memory"
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d '6' "http://localhost:8764/api/apollo/configurations/fusion.sql.default.shuffle.partitions"
```

You'll need to restart the SQL engine after making these changes.

## nyc_taxi

This lab requires Fusion 3.0 or later.

For this lab, you'll need a Postgres DB populated with NYC taxi trip data using the tools provided by:
https://github.com/toddwschneider/nyc-taxi-data

After building the Postgres database, run the `setup_taxi.sh` script.

You'll also need to add the Postgres JDBC driver to the Fusion Spark classpath by adding the following properties to:

`$FUSION_HOME/apps/spark-dist/conf/spark-defaults.conf`:

```
spark.driver.extraClassPath=/Users/timpotter/dev/lw/sstk-local/nyc_taxi/postgresql-9.4.1208.jar
spark.executor.extraClassPath=/Users/timpotter/dev/lw/sstk-local/nyc_taxi/postgresql-9.4.1208.jar
```

Once your database is populated, you can load Fusion from the database using the `load_solr.scala` script provided with this lab.
Be sure to update the JDBC URL in the scala script to match your Postgres DB.

