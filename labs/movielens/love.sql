{
  "sql":"SELECT solr.title as title, avg(rating) as avg_rating FROM ratings INNER JOIN (select movie_id,title from movies where _query_='plot_txt_en:love') as solr ON ratings.movie_id = solr.movie_id GROUP BY title ORDER BY avg_rating DESC LIMIT 10"
}
