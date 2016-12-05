object LoadMovielensIntoSolr {
  val dataDir = "ml-100k"

  def main(args:Array[String]) {
    sqlContext.udf.register("toInt", (str: String) => str.toInt)

    var userDF = sqlContext.read.format("com.databricks.spark.csv")
      .option("delimiter", "|").option("header", "false").load(s"${dataDir}/u.user")
    userDF.registerTempTable("user")
    userDF = sqlContext.sql("select C0 as user_id,toInt(C1) as age,C2 as gender,C3 as occupation,C4 as zip_code from user")
    var writeToSolrOpts = Map("collection" -> "movielens_users", "soft_commit_secs" -> "10")
    userDF.write.format("solr").options(writeToSolrOpts).save

    var itemDF = sqlContext.read.format("com.databricks.spark.csv")
      .option("delimiter", "|").option("header", "false").load(s"${dataDir}/u.item")
    itemDF.registerTempTable("item")

    val selectMoviesSQL =
      """
                            |   SELECT C0 as movie_id, C1 as title,
                            |          C2 as release_date, C3 as video_release_date, C4 as imdb_url,
                            |          C5 as genre_unknown, C6 as genre_action, C7 as genre_adventure,
                            |          C8 as genre_animation, C9 as genre_children, C10 as genre_comedy,
                            |          C11 as genre_crime, C12 as genre_documentary, C13 as genre_drama,
                            |          C14 as genre_fantasy, C15 as genre_filmnoir, C16 as genre_horror,
                            |          C17 as genre_musical, C18 as genre_mystery, C19 as genre_romance,
                            |          C20 as genre_scifi, C21 as genre_thriller, C22 as genre_war,
                            |          C23 as genre_western
                            |     FROM item
                          """.stripMargin

    itemDF = sqlContext.sql(
      selectMoviesSQL)
    itemDF.registerTempTable("item")

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
    itemDF = sqlContext.sql(concatGenreListSQL) // build a multi-valued string field of genres for each movie
    sqlContext.udf.register("genres", (genres: String) => {
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
    itemDF.registerTempTable("item")
    itemDF = sqlContext.sql("select *, genres(genre_list) as genre from item")
    itemDF = itemDF.drop("genre_list")

    // join with omdb metadata to get plot and actors
    sqlContext.udf.register("str2list", (str: String) => {
      str.replace(", ", ",").split(",").toList
    })
    var omdbDF = sqlContext.read.json(s"${dataDir}/omdb_movies.json")
    omdbDF.registerTempTable("omdb")
    omdbDF = sqlContext.sql("select movie_id, title, year, plot as plot_txt_en, str2list(actors) as actor, str2list(director) as director, str2list(language) as language, rated from omdb")
    omdbDF.registerTempTable("omdb2")

    itemDF.registerTempTable("movies")
    var moviesDF = sqlContext.sql("select m.*, o.year, o.actor, o.director, o.language, o.rated, o.plot_txt_en from movies m left outer join omdb2 o on m.movie_id = o.movie_id")
    writeToSolrOpts = Map("collection" -> "movielens_movies", "soft_commit_secs" -> "10")
    moviesDF.write.format("solr").options(writeToSolrOpts).save

    sqlContext.udf.register("secs2ts", (secs: Long) => new java.sql.Timestamp(secs*1000))

    var ratingDF = sqlContext.read.format("com.databricks.spark.csv")
      .option("delimiter","\t").option("header", "false").load(s"${dataDir}/u.data")
    ratingDF.registerTempTable("rating")
    ratingDF = sqlContext.sql("select C0 as user_id, C1 as movie_id, toInt(C2) as rating, secs2ts(C3) as rating_timestamp from rating")
    writeToSolrOpts = Map("collection" -> "movielens_ratings", "soft_commit_secs" -> "10")
    ratingDF.write.format("solr").options(writeToSolrOpts).save

    var zipDF = sqlContext.read.format("com.databricks.spark.csv").option("header", "true").option("delimiter",",").load(s"${dataDir}/us_postal_codes.csv")
    zipDF.registerTempTable("us_postal_codes")
    zipDF = sqlContext.sql("select `Postal Code` as zip_code, `Place Name` as place_name, `State` as state, `State Abbreviation` as state_abbrv, `County` as county,`Latitude` as latitude,`Longitude` as longitude, CONCAT(Latitude,',',Longitude) as geo_point, CONCAT(Latitude,',',Longitude) as geo_location, CONCAT(Latitude,',',Longitude) as geo_location_rpt from us_postal_codes")
    zipDF = zipDF.filter("latitude >= -90 AND latitude <= 90 AND longitude >= -180 AND longitude <= 180")
    zipDF.write.format("solr").options(Map("collection" -> "us_zipcodes")).save
  }
}
LoadMovielensIntoSolr.main(Array())

