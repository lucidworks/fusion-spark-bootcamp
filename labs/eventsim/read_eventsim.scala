var allEvents=sqlContext.read.format("solr").options(Map("collection" -> "eventsim","partition_by" -> "time" ,"time_period" -> "1DAYS","time_stamp_field_name" -> "ts_dt","solr.params" -> "fq=ts_dt:[* TO *]")).load
var someEvents=sqlContext.read.format("solr").options(Map("collection" -> "eventsim","partition_by" -> "time" ,"time_period" -> "1DAYS","time_stamp_field_name" -> "ts_dt","solr.params" -> "fq=ts_dt:[2016-06-19T00:00:00Z TO 2016-06-19T12:00:00Z]")).load
allEvents.show
someEvents.show
