val jdbcUrl = "jdbc:postgresql://localhost/nyc-taxi-data"

// get the max ID from the db to use for partitioning
val getMaxId = sqlContext.jdbc(jdbcUrl, "(select max(id) as maxId from trips) tmp")

val dbOpts = Map(
  "url" -> jdbcUrl,
  "dbtable" -> "trips",
  "partitionColumn" -> "id",
  "numPartitions" -> "4",
  "lowerBound" -> "0",
  "upperBound" -> getMaxId.select("maxId").collect()(0)(0).toString,
  "fetchSize" -> "1000"
)
var jdbcDF = sqlContext.read.format("jdbc").options(dbOpts).load

jdbcDF = jdbcDF.sample(false,0.1,5150)

sqlContext.udf.register("pay", (str: String) => {
  str match {
    case "1" => "credit"
    case "2" => "cash"
    case "3" => "nocharge"
    case "4" => "dispute"
    case _ => str
  }
})

sqlContext.udf.register("rate", (str: String) => {
  str match {
    case "1" => "standard"
    case "2" => "jfk"
    case "3" => "newark"
    case "4" => "nassau_or_westchester"
    case "5" => "negotiated"
    case "6" => "group"
    case _ => str
  }
})

// convert any values less than zero to zero
sqlContext.udf.register("min0", (num: Double) => {
  math.max(num,0d)
})

import java.sql.Timestamp
sqlContext.udf.register("trip_duration", (pickup: Timestamp, dropoff: Timestamp) => {
  math.max(0,math.round(pickup.toInstant().until(dropoff.toInstant(), java.time.temporal.ChronoUnit.SECONDS)))
})

// deal with some data quality issues
jdbcDF = jdbcDF.filter("pickup_latitude >= -90 AND pickup_latitude <= 90 AND pickup_longitude >= -180 AND pickup_longitude <= 180")
jdbcDF = jdbcDF.filter("dropoff_latitude >= -90 AND dropoff_latitude <= 90 AND dropoff_longitude >= -180 AND dropoff_longitude <= 180")
jdbcDF = jdbcDF.filter("passenger_count > 0 AND total_amount > 0 AND trip_distance > 0")
jdbcDF = jdbcDF.filter("pickup_datetime IS NOT NULL AND dropoff_datetime IS NOT NULL")

// use UDFs to massage the data into a more searchable form, such as
// concat the lat/lon cols into a single value expected by solr location fields
jdbcDF.registerTempTable("trips")
val tripsSql =
  """
    | SELECT id,
    | cab_type_id,
    | pickup_datetime,
    | dropoff_datetime,
    | trip_duration(pickup_datetime,dropoff_datetime) as trip_duration_secs,
    | rate(rate_code_id) as rate_code_id,
    | passenger_count,
    | min0(trip_distance) as trip_distance,
    | min0(fare_amount) as fare_amount,
    | min0(extra) as extra,
    | min0(mta_tax) as mta_tax,
    | min0(tip_amount) as tip_amount,
    | min0(tolls_amount) as tolls_amount,
    | min0(total_amount) as total_amount,
    | pay(payment_type) as payment_type,trip_type,
    | CONCAT(pickup_latitude,',',pickup_longitude) as pickup,
    | CONCAT(dropoff_latitude,',',dropoff_longitude) as dropoff
    | FROM trips
  """.stripMargin
jdbcDF = sqlContext.sql(tripsSql)
jdbcDF.printSchema
jdbcDF.write.format("solr").options(Map("collection" -> "nyc_taxi", "batch_size" -> "10000")).save
