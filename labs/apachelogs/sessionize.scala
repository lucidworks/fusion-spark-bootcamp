val opts = Map(
  "zkhost" -> "localhost:9983",
  "collection" -> "apachelogs",
  "query" -> "+clientip:[* TO *] +ts:[* TO *] +bytes:[* TO *] +verb:[* TO *] +response:[* TO *]",
  "split_field" -> "_version_",
  "splits_per_shard" -> "4",
  "fields" -> "id,_version_,clientip,ts,bytes,response,verb")

var logEvents = sqlContext.read.format("solr").options(opts).load
logEvents.cache()
logEvents.registerTempTable("logs")

sqlContext.udf.register("ts2ms", (d: java.sql.Timestamp) => d.getTime)
sqlContext.udf.register("asInt", (b: String) => b.toInt)

val sessions = sqlContext.sql(
  """
    |SELECT *, sum(IF(diff_ms > 30000, 1, 0))
    |OVER (PARTITION BY clientip ORDER BY ts) session_id
    |FROM (SELECT *, ts2ms(ts) - lag(ts2ms(ts))
    |OVER (PARTITION BY clientip ORDER BY ts) as diff_ms FROM logs) tmp
  """.stripMargin)
sessions.registerTempTable("sessions")
sessions.cache()
//sessions.select("clientip", "session_id", "ts").show(100)

var sessionsAgg = sqlContext.sql(
  """
        |SELECT concat_ws('||', clientip,session_id) as id,
        |       first(clientip) as clientip,
        |       min(ts) as session_start,
        |       max(ts) as session_end,
        |       (ts2ms(max(ts)) - ts2ms(min(ts))) as session_len_ms_l,
        |       sum(asInt(bytes)) as total_bytes_l,
        |       count(*) as total_requests_l
        |FROM sessions
        |GROUP BY clientip,session_id
  """.stripMargin)

sessionsAgg.write.format("solr").options(Map("zkhost" -> "localhost:9983", "collection" -> "apachelogs_signals_aggr")).mode(org.apache.spark.sql.SaveMode.Overwrite).save
