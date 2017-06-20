object LoadMovielensIntoSolr {
  val dataDir = "ml-100k"

  def main(args:Array[String]) {
    
    spark.udf.register("toInt", (str: String) => str.toInt)

    var userDF = spark.read.format("com.databricks.spark.csv")
      .option("delimiter", "|").option("header", "false").load(s"${dataDir}/u.user")
    userDF.createOrReplaceTempView("user")
    userDF = spark.sql("select _c0 as user_id,toInt(_c1) as age,_c2 as gender,_c3 as occupation,_c4 as zip_code from user")
    var writeToSolrOpts = Map("collection" -> "users", "soft_commit_secs" -> "10")
    userDF.write.format("solr").options(writeToSolrOpts).save

    var itemDF = spark.read.format("com.databricks.spark.csv")
      .option("delimiter", "|").option("header", "false").load(s"${dataDir}/u.item")
    itemDF.createOrReplaceTempView("item")

    val selectMoviesSQL =
      """
                            |   SELECT _c0 as movie_id, _c1 as title,
                            |          _c2 as release_date, _c3 as video_release_date, _c4 as imdb_url,
                            |          _c5 as genre_unknown, _c6 as genre_action, _c7 as genre_adventure,
                            |          _c8 as genre_animation, _c9 as genre_children, _c10 as genre_comedy,
                            |          _c11 as genre_crime, _c12 as genre_documentary, _c13 as genre_drama,
                            |          _c14 as genre_fantasy, _c15 as genre_filmnoir, _c16 as genre_horror,
                            |          _c17 as genre_musical, _c18 as genre_mystery, _c19 as genre_romance,
                            |          _c20 as genre_scifi, _c21 as genre_thriller, _c22 as genre_war,
                            |          _c23 as genre_western
                            |     FROM item
                          """.stripMargin

    itemDF = spark.sql(selectMoviesSQL)
    itemDF.createOrReplaceTempView("item")

    val concatGenreListSQL =
      """
                               |    SELECT *,
                               |           concat(genre_unknown,genre_action,genre_adventure,genre_animation,
                               |                  genre_children,genre_comedy,genre_crime,genre_documentary,
                               |                  genre_drama,genre_fantasy,genre_filmnoir,genre_horror,
                               |                  genre_musical,genre_mystery,genre_romance,genre_scifi,
                               |                  genre_thriller,genre_war,genre_western) as genre_list
                               |     FROM item
                             """.stripMargin
    itemDF = spark.sql(concatGenreListSQL) // build a multi-valued string field of genres for each movie
    spark.udf.register("genres", (genres: String) => {
      var list = scala.collection.mutable.ListBuffer.empty[String]
      var arr = genres.toCharArray
      val g = List("unknown","action","adventure","animation","children",
        "comedy","crime","documentary","drama","fantasy",
        "filmnoir","horror","musical","mystery","romance",
        "scifi","thriller","war","western")
      for (i <- arr.indices) {
        if (arr(i) == '1')
          list += g(i)
      }
      list
    })
    itemDF.createOrReplaceTempView("item")
    itemDF = spark.sql("select *, genres(genre_list) as genre from item")
    itemDF = itemDF.drop("genre_list")

    // join with omdb metadata to get plot and actors
    spark.udf.register("str2list", (str: String) => {
      str.replace(", ", ",").split(",").toList
    })
    var omdbDF = spark.read.json(s"${dataDir}/omdb_movies.json")
    omdbDF.createOrReplaceTempView("omdb")
    omdbDF = spark.sql("select movie_id, title, year, plot as plot_txt_en, str2list(actors) as actor, str2list(director) as director, str2list(language) as language, rated from omdb")
    omdbDF.createOrReplaceTempView("omdb2")

    itemDF.createOrReplaceTempView("movies")
    var moviesDF = spark.sql("select m.*, o.year, o.actor, o.director, o.language, o.rated, o.plot_txt_en from movies m left outer join omdb2 o on m.movie_id = o.movie_id")
    writeToSolrOpts = Map("collection" -> "movies", "soft_commit_secs" -> "10")
    moviesDF.write.format("solr").options(writeToSolrOpts).save

    spark.udf.register("secs2ts", (secs: Long) => new java.sql.Timestamp(secs*1000))

    var ratingDF = spark.read.format("com.databricks.spark.csv")
      .option("delimiter","\t").option("header", "false").load(s"${dataDir}/u.data")
    ratingDF.createOrReplaceTempView("rating")
    ratingDF = spark.sql("select _c0 as user_id, _c1 as movie_id, toInt(_c2) as rating, secs2ts(_c3) as rating_timestamp from rating")
    writeToSolrOpts = Map("collection" -> "ratings", "soft_commit_secs" -> "10")
    ratingDF.write.format("solr").options(writeToSolrOpts).save

    var zipDF = spark.read.format("com.databricks.spark.csv").option("header", "true").option("delimiter",",").load(s"${dataDir}/us_postal_codes.csv")
    zipDF.createOrReplaceTempView("us_postal_codes")
    zipDF = spark.sql("select `Postal Code` as zip_code, `Place Name` as place_name, `State` as state, `State Abbreviation` as state_abbrv, `County` as county,`Latitude` as latitude,`Longitude` as longitude, CONCAT(Latitude,',',Longitude) as geo_point, CONCAT(Latitude,',',Longitude) as geo_location, CONCAT(Latitude,',',Longitude) as geo_location_rpt from us_postal_codes")
    zipDF = zipDF.filter("latitude >= -90 AND latitude <= 90 AND longitude >= -180 AND longitude <= 180")
    zipDF.write.format("solr").options(Map("collection" -> "zipcodes")).save
  }
}
LoadMovielensIntoSolr.main(Array())
System.exit(0)

