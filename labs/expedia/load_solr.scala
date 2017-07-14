val zkhost = "localhost:9983"
val dataDir = "/Users/timpotter/dev/lw/sstk-local/expedia"

sqlContext.udf.register("toInt", (str: String) => str.toInt)

// Load test.csv into Solr
var testDF = sqlContext.read.format("com.databricks.spark.csv")
               .option("header", "true").load(s"${dataDir}/test.csv")
testDF.registerTempTable("test")
testDF = sqlContext.sql("SELECT * FROM test")
var writeToSolrOpts = Map(
  "zkhost" -> zkhost,
  "collection" -> "expedia_test",
  "soft_commit_secs" -> "10")
testDF.write.format("solr").options(writeToSolrOpts).save

// Load train.csv into Solr
var trainDF = sqlContext.read.format("com.databricks.spark.csv")
                .option("header", "true").load(s"${dataDir}/train.csv")
trainDF.registerTempTable("train")
trainDF = sqlContext.sql("SELECT * FROM train")
writeToSolrOpts = Map(
  "zkhost" -> zkhost,
  "collection" -> "expedia_train",
  "soft_commit_secs" -> "10")
trainDF.write.format("solr").options(writeToSolrOpts).save

// Load destinations.csv into Solr
var destDF = sqlContext.read.format("com.databricks.spark.csv")
               .option("header", "true").load(s"${dataDir}/destinations.csv")
destDF.registerTempTable("destinations")
destDF = sqlContext.sql("SELECT * FROM destinations")
writeToSolrOpts = Map(
  "zkhost" -> zkhost,
  "collection" -> "expedia_destinations",
  "soft_commit_secs" -> "10")
destDF.write.format("solr").options(writeToSolrOpts).save
