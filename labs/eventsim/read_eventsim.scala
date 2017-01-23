val allEventsOpts = Map(
   "collection" -> "eventsim",
   "partition_by" -> "time",
   "rows" -> "10000",
   "time_period" -> "1DAYS",
   "time_stamp_field_name" -> "ts",
   "solr.params" -> "fq=ts:[* TO *]")
val allEvents = sqlContext.read.format("solr").options(allEventsOpts).load
allEvents.show

val someEventsOpts = Map(
  "collection" -> "eventsim",
  "partition_by" -> "time",
  "rows" -> "10000",
  "time_period" -> "1DAYS",
  "time_stamp_field_name" -> "ts",
  "solr.params" -> "fq=ts:[2016-06-19T00:00:00Z TO 2016-06-19T12:00:00Z]")
val someEvents = sqlContext.read.format("solr").options(someEventsOpts).load
someEvents.show
