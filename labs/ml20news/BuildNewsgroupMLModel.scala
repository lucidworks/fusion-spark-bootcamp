import java.io.Serializable

import com.lucidworks.spark.fusion.FusionMLModelSupport
import com.lucidworks.spark.ml.feature.LuceneTextAnalyzerTransformer
import org.apache.spark.{SparkConf, SparkContext}
import org.apache.spark.ml.{Pipeline, PipelineStage}
import org.apache.spark.ml.classification.NaiveBayes
import org.apache.spark.ml.evaluation.MulticlassClassificationEvaluator
import org.apache.spark.ml.feature._
import org.apache.spark.ml.tuning.CrossValidator
import org.apache.spark.ml.tuning.{CrossValidatorModel, ParamGridBuilder}
import org.apache.spark.mllib.evaluation.MulticlassMetrics
import org.apache.spark.sql.SQLContext

/** 
  * An example of building a spark.ml classification model to predict the newsgroup of
  * articles from the 20 newsgroups data (see [[http://qwone.com/~jason/20Newsgroups/]])
  * hosted in a Fusion collection.
  */
object BuildNewsgroupMLModel extends Serializable {

  val LabelCol = "label"
  val WordsCol = "words"
  val PredictionCol = "prediction"
  val FeaturesCol = "features"
  val PredictedLabelCol = "predictedLabel"
  val DefaultQuery = "content_txt:[* TO *] AND newsgroup_s:[* TO *]"
  val DefaultLabelField = "newsgroup_s"
  val DefaultContentFields = "content_txt,subject"
  val DefaultCollection = "ml20news"
  val DefaultSample = "1.0"
  val WhitespaceTokSchema =
    """{ "analyzers": [{ "name": "ws_tok", "tokenizer": { "type": "whitespace" } }],
      |  "fields": [{ "regex": ".+", "analyzer": "ws_tok" }] }""".stripMargin
  val StdTokLowerSchema =
    """{ "analyzers": [{ "name": "std_tok_lower", "tokenizer": { "type": "standard" },
      |                  "filters": [{ "type": "lowercase" }] }],
      |  "fields": [{ "regex": ".+", "analyzer": "std_tok_lower" }] }""".stripMargin

  //val sqlContext: SQLContext = ???

  def main(args:Array[String]) {

    val labelField = DefaultLabelField
    val contentFields = DefaultContentFields.split(",").map(_.trim)
    val sampleFraction = DefaultSample.toDouble

    val fields = s"""id,$labelField,${contentFields.mkString(",")}"""

    val options = Map(
      "collection" -> DefaultCollection,
      "query" -> DefaultQuery,
      "fields" -> fields)

    println("Reading data from Solr using options: "+options)

    val solrData = sqlContext.read.format("solr").options(options).load
    val sampledSolrData = solrData.sample(withReplacement = false, sampleFraction)

    // Configure an ML pipeline, which consists of the following stages:
    // index string labels, analyzer, hashingTF, classifier model, convert predictions to string labels.

    // ML needs labels as numeric (double) indexes ... our training data has string labels, convert using a StringIndexer
    // see: https://spark.apache.org/docs/1.6.0/api/java/index.html?org/apache/spark/ml/feature/StringIndexer.html
    val labelIndexer = new StringIndexer().setInputCol(labelField).setOutputCol(LabelCol).fit(sampledSolrData)
    val analyzer = new LuceneTextAnalyzerTransformer().setInputCols(contentFields).setOutputCol(WordsCol)

    // Vectorize!
    val hashingTF = new HashingTF().setInputCol(WordsCol).setOutputCol(FeaturesCol)

    val nb =  new NaiveBayes()
    val estimatorStage:PipelineStage = nb
    println(s"Using estimator: $estimatorStage")
    val labelConverter = new IndexToString().setInputCol(PredictionCol)
      .setOutputCol(PredictedLabelCol).setLabels(labelIndexer.labels)
    val pipeline = new Pipeline().setStages(Array(labelIndexer, analyzer, hashingTF, estimatorStage, labelConverter))
    val Array(trainingData, testData) = sampledSolrData.randomSplit(Array(0.7, 0.3))
    val evaluator = new MulticlassClassificationEvaluator().setLabelCol(LabelCol)
      .setPredictionCol(PredictionCol).setMetricName("precision")

    // We use a ParamGridBuilder to construct a grid of parameters to search over,
    // with 3 values for hashingTF.numFeatures, 2 values for lr.regParam, 2 values for
    // analyzer.analysisSchema, and both possibilities for analyzer.prefixTokensWithInputCol.
    // This grid will have 3 x 2 x 2 x 2 = 24 parameter settings for CrossValidator to choose from.
    val paramGrid = new ParamGridBuilder()
      .addGrid(hashingTF.numFeatures, Array(5000, 10000))
      .addGrid(analyzer.analysisSchema, Array(WhitespaceTokSchema, StdTokLowerSchema))
      .addGrid(analyzer.prefixTokensWithInputCol)
      .addGrid(nb.smoothing, Array(1.0, 0.5, 0.25)).build

    // We now treat the Pipeline as an Estimator, wrapping it in a CrossValidator instance.
    // This will allow us to jointly choose parameters for all Pipeline stages.
    // A CrossValidator requires an Estimator, a set of Estimator ParamMaps, and an Evaluator.
    val cv = new CrossValidator().setEstimator(pipeline).setEvaluator(evaluator)
      .setEstimatorParamMaps(paramGrid).setNumFolds(4)
    val cvModel = cv.fit(trainingData)

    // save it to disk
    cvModel.write.overwrite.save("ml-pipeline-model")

    // read it off disk
    val loadedCvModel = CrossValidatorModel.load("ml-pipeline-model")

    val predictions = loadedCvModel.transform(testData)
    predictions.cache

    val accuracyCrossFold = evaluator.evaluate(predictions)
    println(s"Cross-Fold Test Error = ${1.0 - accuracyCrossFold}")

    // TODO: remove - debug
    //for (r <- predictions.select("id", labelField, PredictedLabelCol).sample(false, 0.1).collect) {
    //  println(s"${r(0)}: actual=${r(1)}, predicted=${r(2)}")
    //}

    val metrics = new MulticlassMetrics(predictions.select(PredictionCol, LabelCol)
      .map(r => (r.getDouble(0), r.getDouble(1))))

    // output the Confusion Matrix
    println(s"""Confusion Matrix
                          |${metrics.confusionMatrix}\n""".stripMargin)

    // compute the false positive rate per label
    println(s"""\nF-Measure: ${metrics.fMeasure}
                          |label\tfpr\n""".stripMargin)
    val labels = labelConverter.getLabels
    for (i <- labels.indices)
      println(s"${labels(i)}\t${metrics.falsePositiveRate(i.toDouble)}")

    val modelId = "ml20news"
    var metadata = new java.util.HashMap[String, String]()

    FusionMLModelSupport.saveModelInLocalFusion(sqlContext.sparkContext, modelId, loadedCvModel, metadata)
  }
}
BuildNewsgroupMLModel.main(Array())
System.exit(0)
