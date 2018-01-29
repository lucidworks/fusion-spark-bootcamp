val allEventsOpts = Map(
   "collection" -> "eventsim",
   "partition_by" -> "time",
   "rows" -> "10000",
   "time_period" -> "1DAYS",
   "timestamp_field_name" -> "ts",
   "fields" -> "id,ts,status,method",
   "solr.params" -> "fq=ts:[* TO *]")
val allEvents = spark.read.format("solr").options(allEventsOpts).load
allEvents.show

val someEventsOpts = Map(
  "collection" -> "eventsim",
  "partition_by" -> "time",
  "rows" -> "10000",
   "fields" -> "id,ts,status,method",
  "time_period" -> "1DAYS",
  "timestamp_field_name" -> "ts",
  "solr.params" -> "fq=ts:[2016-06-19T00:00:00Z TO 2016-06-19T12:00:00Z]")
val someEvents = spark.read.format("solr").options(someEventsOpts).load
someEvents.show
