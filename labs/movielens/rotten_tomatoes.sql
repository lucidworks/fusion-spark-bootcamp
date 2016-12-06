{
  "sql":"SELECT m.title as title, solr.aggAvg as aggAvg FROM movies m INNER JOIN (SELECT movie_id, COUNT(*) as num_ratings, avg(rating) as aggAvg FROM movielens_ratings GROUP BY movie_id HAVING num_ratings > 100 ORDER BY aggAvg ASC LIMIT 10) as solr ON solr.movie_id = m.movie_id ORDER BY aggAvg ASC"
}
