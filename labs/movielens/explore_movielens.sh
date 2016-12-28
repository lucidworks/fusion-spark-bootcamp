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

# find data assets about movies
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/_search?keyword=movies"

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

# explore the "us_zipcodes" table
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/us_zipcodes"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/us_zipcodes/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/us_zipcodes/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/us_zipcodes/rows"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/us_zipcodes/columns/geo_location_rpt?facet.heatmap.geom=%5B%22-126+23%22+TO+%22-67+51%22%5d&facet.heatmap.gridLevel=3"

# create a view of joined users and zipcodes
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" -d '{
  "sql":"SELECT user_id, age, gender, occupation, u.zip_code, place_name, state, county, geo_location, geo_location_rpt FROM users u INNER JOIN (select place_name, state, county, geo_location, geo_location_rpt, zip_code from us_zipcodes) z ON u.zip_code = z.zip_code",
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
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-type:application/json" --data-binary @minn_zipcodes.json \
  "$FUSION_API/catalog/geo/assets"

curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/minn_zipcodes"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/minn_zipcodes/schema"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/minn_zipcodes/count"
curl -u $FUSION_USER:$FUSION_PASS "$FUSION_API/catalog/geo/assets/minn_zipcodes/rows"

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

curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" --data-binary @join.sql "$FUSION_API/catalog/fusion/query"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" --data-binary @love.sql "$FUSION_API/catalog/fusion/query"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" --data-binary @gender.sql "$FUSION_API/catalog/fusion/query"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" --data-binary @rotten_tomatoes.sql "$FUSION_API/catalog/fusion/query"
curl -u $FUSION_USER:$FUSION_PASS -XPOST -H "Content-Type:application/json" --data-binary @streaming_join.json "$FUSION_API/catalog/fusion/query"

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
