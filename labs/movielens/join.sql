{
  "sql":"SELECT m.title as title, solr.aggCount as aggCount FROM movies m INNER JOIN (SELECT movie_id, COUNT(*) as aggCount FROM ratings WHERE rating >= 4 GROUP BY movie_id ORDER BY aggCount desc LIMIT 10) as solr ON solr.movie_id = m.movie_id ORDER BY aggCount DESC"
}
