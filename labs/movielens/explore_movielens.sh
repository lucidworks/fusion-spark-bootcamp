#!/bin/bash

while [ -h "$SETUP_SCRIPT" ] ; do
  ls=`ls -ld "$SETUP_SCRIPT"`
  # Drop everything prior to ->
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    SETUP_SCRIPT="$link"
  else
    SETUP_SCRIPT=`dirname "$SETUP_SCRIPT"`/"$link"
  fi
done

LABS_TIP=`dirname "$SETUP_SCRIPT"`/../..
LABS_TIP=`cd "$LABS_TIP"; pwd`

source "$LABS_TIP/myenv.sh"

if [ "$FUSION_PASS" == "" ]; then
  echo -e "ERROR: Must provide a valid password for Fusion user: $FUSION_USER"
  exit 1
fi

# explore the user table

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/columns/gender"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/columns/occupation"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/columns/age"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/users/columns/zip_code"

# explore the movies table

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/actor"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/rated"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/year"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/director"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/genre"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/language"

# apply filter to see only movies about "love"
# full-text queries cannot be evaluated by Spark, they have to be pushed down into Solr
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/count?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/rows?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/actor?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/rated?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/year?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/director?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/genre?fq=plot_txt_en:love"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movies/columns/language?fq=plot_txt_en:love"

# explore the "ratings" table
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/columns/rating"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/columns/rating_timestamp"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings/columns/rating_timestamp?start=1997-09-20T03:05:10.000Z&end=1997-12-20T03:05:10.000Z"

# explore the "zipcodes" table
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/zipcodes"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/zipcodes/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/zipcodes/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/zipcodes/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/zipcodes/columns/geo_location_rpt?facet.heatmap.geom=%5B%22-126+23%22+TO+%22-67+51%22%5d&facet.heatmap.gridLevel=3"

# create a view of joined users and zipcodes
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"SELECT user_id, age, gender, occupation, u.zip_code, place_name, state, county, geo_location, geo_location_rpt FROM users u INNER JOIN (select place_name, state, county, geo_location, geo_location_rpt, zip_code from zipcodes) z ON u.zip_code = z.zip_code",
  "cacheResultsAs": "us_user_location"
}' "$FUSION_API/catalog/fusion/query"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/age"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/county"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/gender"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/geo_location"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/geo_location_rpt"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/occupation"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/place_name"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/state"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/us_user_location/columns/zip_code"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets"

# the data explorer tool needs to know that any filters on geo-spatial or text fields need to be pushed into Solr
# so the best thing to do is just define a new "view" in the catalog
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" "$FUSION_API/catalog/fusion/assets" --data-binary @<(cat <<EOF
{
  "name": "minn_zipcodes",
  "assetType": "table",
  "projectId": "fusion",
  "format": "solr",
  "description":"zips around minn",
  "options": [
     "collection -> zipcodes",
     "fields -> zip_code,place_name,state,county,geo_point,geo_location,geo_location_rpt", 
     "query -> {!geofilt sfield=geo_location pt=44.9609,-93.2642 d=50}",
     "solr.params -> sort=id asc"
  ]
}
EOF
)

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_zipcodes"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_zipcodes/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_zipcodes/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_zipcodes/rows"

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"SELECT user_id, age, gender, occupation, u.zip_code, place_name, state, county, geo_location, geo_location_rpt FROM users u INNER JOIN minn_zipcodes z ON u.zip_code = z.zip_code",
  "cacheResultsAs": "minn_users"
}' "$FUSION_API/catalog/fusion/query"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/age"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/county"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/gender"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/occupation"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/place_name"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/state"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/minn_users/columns/zip_code"

# explore a join of movies and ratings
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"SELECT m.title as title, r.* FROM ratings r INNER JOIN movies m ON r.movie_id = m.movie_id",
  "cacheResultsAs": "movie_ratings"
}' "$FUSION_API/catalog/fusion/query"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/columns/rating_timestamp?start=1997-09-20T03:05:10.000Z&end=1997-12-20T03:05:10.000Z"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/count?fq=user_id:30"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/movie_ratings/rows?fq=user_id:30"

# fire off some custom SQL

echo -e "\n\nExample: push-down subquery into Solr to compute aggregation"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" "$FUSION_API/catalog/fusion/query" --data-binary @<(cat <<EOF
{
 "sql":"SELECT m.title as title, solr.aggCount as aggCount FROM movies m INNER JOIN (SELECT movie_id, COUNT(*) as aggCount FROM ratings WHERE rating >= 4 GROUP BY movie_id ORDER BY aggCount desc LIMIT 10) as solr ON solr.movie_id = m.movie_id ORDER BY aggCount DESC"
}
EOF
)

echo -e "\n\nExample: push-down subquery into Solr to find movies about love"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" "$FUSION_API/catalog/fusion/query" --data-binary @<(cat <<EOF
{
"sql":"SELECT solr.title as title, avg(rating) as avg_rating FROM ratings INNER JOIN (select movie_id,title from movies where _query_='plot_txt_en:love') as solr ON ratings.movie_id = solr.movie_id GROUP BY title ORDER BY avg_rating DESC LIMIT 10"
}
EOF
)

echo -e "\n\n:Example: compute num ratings by gender using join between ratings and user table"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" "$FUSION_API/catalog/fusion/query" --data-binary @<(cat <<EOF
{
  "sql": "SELECT u.gender as gender, COUNT(*) as aggCount FROM users u INNER JOIN ratings r ON u.user_id = r.user_id GROUP BY gender"
}
EOF
)

echo -e "\n\nExample: some rotten tomatoes (movies with low avg rating); aggregations computed by Solr"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" "$FUSION_API/catalog/fusion/query" --data-binary @<(cat <<EOF
{
 "sql":"SELECT m.title as title, solr.aggAvg as aggAvg FROM movies m INNER JOIN (SELECT movie_id, COUNT(*) as num_ratings, avg(rating) as aggAvg FROM ratings GROUP BY movie_id HAVING num_ratings > 100 ORDER BY aggAvg ASC LIMIT 10) as solr ON solr.movie_id = m.movie_id ORDER BY aggAvg ASC"
}
EOF
) 

echo -e "\n\nExample: execute streaming expressions too"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" "$FUSION_API/catalog/fusion/query" --data-binary @<(cat <<EOF
{
  "solr":"hashJoin(search(ratings, q=*:*, qt=\"/export\", fl=\"user_id,movie_id,rating\", sort=\"movie_id asc\", partitionKeys=\"movie_id\"), hashed=search(movies, q=*:*, fl=\"movie_id,title\", qt=\"/export\", sort=\"movie_id asc\",partitionKeys=\"movie_id\"),on=\"movie_id\")", 
  "collection":"ratings",
  "requestHandler":"/stream"
}
EOF
)

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"SELECT u.user_id as user_id, age, gender, occupation, place_name, county, state, zip_code, geo_location_rpt, title, movie_id, rating, rating_timestamp FROM minn_users u INNER JOIN movie_ratings m ON u.user_id = m.user_id",
  "cacheResultsAs": "ratings_by_minn_users"
}' "$FUSION_API/catalog/fusion/query"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/user_id"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/age"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/gender"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/occupation"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/place_name"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/county"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/state"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/zip_code"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/geo_location_rpt"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/title"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/movie_id"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/rating"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/rating_timestamp"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/count?fq=gender:F"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/rows?fq=gender:F"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/occupation?fq=gender:F"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/count?fq=gender:F&fq=occupation:educator"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/rows?fq=gender:F&fq=occupation:educator"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/fusion/assets/ratings_by_minn_users/columns/occupation?fq=gender:F&fq=occupation:educator"
