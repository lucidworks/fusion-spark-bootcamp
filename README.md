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

Download and install the latest version of Fusion from lucidworks.com. Take note of the location where you installed Fusion, such as /opt/lucidworks/fusion. We'll refer to this location as $FUSION_HOME hereafter.

Start Fusion by doing:
```
cd $FUSION_HOME
bin/fusion start
```

Login to the Fusion Admin UI in your browser at: http://localhost:8764

If this is the first time you're running Fusion, then you will be prompted to set a password for the default "admin" user.

Edit the `myenv.sh` script to set environment specific variables used by lab setup scripts.

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

Clone the spark-solr project from github:

```
git clone https://github.com/lucidworks/spark-solr.git
````

Run `mvn package -DskipTests`

Set the location of the spark-solr directory in the `myenv.sh` script, e.g.

```
SPARK_SOLR_HOME=/Users/timpotter/dev/lw/projects/spark-solr
```
Run the `labs/eventsim/setup_eventsim.sh` script to create the Fusion objects needed to support this lab.

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

Run the `labs/movielens/setup_movielens.sh` script to create collections and catalog objects in Fusion.

The setup script downloads the ml-100k data set from http://files.grouplens.org/datasets/movielens/ml-100k.zip and extracts it to `labs/movielens/ml-100k`.

The setup script also invokes the Spark shell to load data into Solr, see the load_solr.scala script for more details.

Exit the spark-shell and start the SQL engine service in Fusion by doing: 

```
cd $FUSION_HOME
bin/spark-sql-engine start
```

The SQL engine enforces security using the Fusion authentication and authorization APIs. Consequently, you need to create
a Fusion user to access the SQL engine. You should grant the following permissions to the SQL engine user:
 
```
GET,POST:/catalog/**
GET:/solr/**
```
 
Alternatively, you can just use the admin user by doing:

```
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d 'admin' "http://localhost:8764/api/apollo/configurations/catalog.jdbc.user"
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d '********' "http://localhost:8764/api/apollo/configurations/catalog.jdbc.pass?secret=true"
```

_replace `*******` with the correct password_

Test the Catalog API endpoint by executing the following request:

```
curl -XPOST -H "Content-Type:application/json" --data-binary @join.sql http://localhost:8765/api/v1/catalog/movielens/query
```
_NOTE: It make take a few seconds the first time you run a query for Spark to distribute the Fusion shaded JAR to worker processes._

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

