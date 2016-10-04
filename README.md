Fusion Spark Bootcamp
========

This project contains examples and labs for learning how to use Fusion's Spark features.

* apachelogs: Run a custom script job in Scala that performs sessionization (using a SQL window function) and then computes some aggregations for each user session
* mlsvm: Classify sentiment of tweets using SVM model trained with Spark MLlib
* ml20news: 20 newsgroup classifier based on Spark ML pipeline
* movielens: Scala script to load movielens data into Fusion

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

For this lab, you need to download the Movielens 100K dataset found at: http://grouplens.org/datasets/movielens/.
After downloading the zip file, extract it locally and take note of the directory, such as /tmp/ml-100k.

Run the `labs/movielens/setup_movielens.sh` script to create collections and catalog objects in Fusion.

Copy the omdb_movies.json and us_postal_codes.csv files into the data directory (where you extracted the ml-100k data set). These additional data files contain location information for US zip codes and plot descriptions for movies.

Edit the `labs/movielens/load_solr.scala` to set the correct zkhost and dataDir variables in the script. 
Take a moment to understand the load_solr.scala script to see how it populates the movielens collections in Solr.

Launch the spark-shell in Fusion by doing:
```
$FUSION_HOME/bin/spark-shell
```

Type `:paste` at the prompt and paste in the contents of the load_solr.scala script included with the lab.

`ctrl-d` to run the Scala script.

Exit the spark-shell and start the SQL engine service in Fusion by doing: 
```
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
curl -u admin:password123 -H 'Content-type:application/json' -X PUT -d 'password123' "http://localhost:8764/api/apollo/configurations/catalog.jdbc.pass?secret=true"
```

Test the Catalog API endpoint by executing the following request:

```
curl -XPOST -H "Content-Type:application/json" --data-binary @join.sql http://localhost:8765/api/v1/catalog/movielens/query
```
_NOTE: It make take a few seconds the first time you run a query for Spark to distribute the Fusion shaded JAR to worker processes._
