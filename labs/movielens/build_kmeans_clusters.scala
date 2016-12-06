// NOTE: intended to be run in the spark-shell
import com.lucidworks.spark.analysis.LuceneTextAnalyzer
import com.lucidworks.spark.fusion.FusionMLModelSupport
import org.apache.spark.mllib.feature.{Normalizer, HashingTF}
import org.apache.spark.mllib.linalg.{Vector}
import org.apache.spark.sql.Row
import org.apache.spark.mllib.clustering.{KMeans, KMeansModel}

// read movie title & plot from solr
val moviesInSolrOpts = Map("collection" -> "movielens_movies", "fields" -> "title,plot_txt_en")
val movies = sqlContext.read.format("solr").options(moviesInSolrOpts).load
//movies.printSchema

val numClusters = 30
val modelId = "movielens-kmeans-k"+numClusters
val modelDir = "movielens-kmeans-k"+numClusters+"-"+java.util.UUID.randomUUID.toString
val numFeatures = 100000
val numIterations = 100
val featureFields = List("title", "plot_txt_en")

val textAnalysisSchema =
  """
    |{
    |  "analyzers":[
    |    {
    |      "name":"StdTokLowerStop",
    |      "tokenizer": { "type":"standard" },
    |      "filters":[
    |        { "type":"lowercase" },
    |        { "type":"stop" }
    |      ]
    |    }
    |  ],
    |  "fields":[{ "regex": ".+", "analyzer": "StdTokLowerStop" }]
    |}
  """.stripMargin

def row2vec(row: Row, featureFields: List[String], numFeatures: Int, textAnalysisSchema: String): Vector = {
  var textAnalyzer: LuceneTextAnalyzer = new LuceneTextAnalyzer(textAnalysisSchema)
  val hashingTF = new HashingTF(numFeatures)
  val normalizer = new Normalizer()
  // get the value for each feature file, analyze it to generate a
  // list of terms and then flatten the terms into a single list
  val terms = featureFields.map { f => textAnalyzer.analyze(f, row.getString(row.fieldIndex(f))) }.flatten
  normalizer.transform(hashingTF.transform(terms))
}

val movieVectors = movies.map { row => row2vec(row, featureFields, numFeatures, textAnalysisSchema) }
movieVectors.cache

val kmeansModel : KMeansModel = KMeans.train(movieVectors, numClusters, numIterations)

// Save the model to local dir & Fusion blob store
kmeansModel.save(sqlContext.sparkContext, modelDir)

var metadata = new java.util.HashMap[String, String]()
metadata.put("numFeatures", numFeatures.toString)
metadata.put("featureFields", featureFields.mkString(","))
metadata.put("analyzerJson", textAnalysisSchema)
metadata.put("normalizer", "Y")
FusionMLModelSupport.saveModelInLocalFusion(sqlContext.sparkContext, modelId, kmeansModel, metadata)

