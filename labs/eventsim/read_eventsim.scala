val zkhost = "localhost:9983/lwfusion/3.0.0/solr"
var allEvents=sqlContext.read.format("solr").options(Map("zkHost" -> zkhost, "collection" -> "eventsim","partition_by" -> "time" ,"time_period" -> "1DAYS","time_stamp_field_name" -> "ts","solr.params" -> "fq=ts:[* TO *]")).load
var someEvents=sqlContext.read.format("solr").options(Map("zkHost" -> zkhost, "collection" -> "eventsim","partition_by" -> "time" ,"time_period" -> "1DAYS","time_stamp_field_name" -> "ts","solr.params" -> "fq=ts:[2016-06-19T00:00:00Z TO 2016-06-19T12:00:00Z]")).load
allEvents.show
someEvents.show
