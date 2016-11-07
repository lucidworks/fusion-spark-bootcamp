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

// deal with some data quality issues in the lat/lon cols
jdbcDF = jdbcDF.filter("pickup_latitude >= -90 AND pickup_latitude <= 90 AND pickup_longitude >= -180 AND pickup_longitude <= 180")
jdbcDF = jdbcDF.filter("dropoff_latitude >= -90 AND dropoff_latitude <= 90 AND dropoff_longitude >= -180 AND dropoff_longitude <= 180")

// concat the lat/lon cols into a single value expected by solr location fields
jdbcDF.registerTempTable("trips")
jdbcDF = sqlContext.sql("SELECT id,cab_type_id,vendor_id,pickup_datetime,dropoff_datetime,store_and_fwd_flag,rate_code_id,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type, CONCAT(pickup_latitude,',',pickup_longitude) as pickup, CONCAT(dropoff_latitude,',',dropoff_longitude) as dropoff FROM trips")
jdbcDF.printSchema
jdbcDF.write.format("solr").options(Map("collection" -> "nyc_taxi", "batch_size" -> "6000")).mode(org.apache.spark.sql.SaveMode.Overwrite).save
