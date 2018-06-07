import org.apache.spark.sql.{DataFrame, Dataset}
import com.johnsnowlabs.nlp.annotator._
import com.johnsnowlabs.nlp.annotators.ner.NerConverter
import com.johnsnowlabs.nlp.base._
import com.johnsnowlabs.util.Benchmark
import com.sun.rowset.internal.Row
import org.apache.spark.ml.Pipeline
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions.udf

/*
 * NOTE: This script is a standalone file to help you
 * see the custom transformScala script written for
 * this job. It is encoded as a .json string in
 * process_ner_job.json file. Thus, making any edits
 * on this file will not affect the job in anyways.
 */
def splitTokens(str: String): List[String] = {
  val foo = str.split("@")
  return foo.toList
}

def splitWords(str: String): (String, String) = {
  // str is of format: word->London#result->LOC
  val xs = str.split("#")
  var first = ""
  var secnd = ""
  try {
    first = xs(0).substring(6)
    secnd = xs(1).substring(8)
  } catch {
    case e: Exception => {
      first = "ERROR: " + str
      secnd = "ERROR: " + str
    }
  }
  (first, secnd)
}

def massageList(vals: List[String]): List[(String, String)] = {
  for (e <- vals)
    yield splitWords(e)
}

def transform(inputDF: Dataset[Row]): Dataset[Row] = {
  val document = new DocumentAssembler()
    .setInputCol("text")
    .setOutputCol("document")
  val token = new Tokenizer()
    .setInputCols("document")
    .setOutputCol("token")
  val normalizer = new Normalizer()
    .setInputCols("token")
    .setOutputCol("normal")
  val ner = NerDLModel.pretrained()
    .setInputCols("normal", "document")
    .setOutputCol("ner")
  val nerConverter = new NerConverter()
    .setInputCols("document", "normal", "ner")
    .setOutputCol("ner_converter")
  val finisher = new Finisher()
    .setInputCols("ner", "ner_converter")
    .setIncludeMetadata(true)
    .setOutputAsArray(false)
    .setCleanAnnotations(false)
  val pipeline = new Pipeline().
    setStages(Array(document, token, normalizer, ner, nerConverter, finisher))
  val intext = inputDF.toDF
  val result = pipeline.fit(Seq.empty[String].toDS.toDF("text")).transform(intext)
  val only_ner = result.select("text","finished_ner")
  val ner_by_tokens = only_ner.map(s => (s.getAs[String](0), splitTokens(s.getAs[String](1))))
  val ner_by_words = ner_by_tokens.map(s => (s._1, massageList(s._2)))
  val ner_words_rdd = ner_by_words.rdd
  val mapped = ner_words_rdd.map{s => (s._1, s._2.groupBy{k => k._2})}
  val mapped_pruned = mapped.map(s => (s._1, s._2.mapValues(_.map(_._1)).map(identity)))
  var backToDf = spark.createDataFrame(mapped_pruned)
  val oUDF = udf((pair: (Map[String, Seq[String]])) => pair.getOrElse("O", Seq.empty[String]))
  val lUDF = udf((pair: (Map[String, Seq[String]])) => pair.getOrElse("I-LOC", Seq.empty[String]))
  val pUDF = udf((pair: (Map[String, Seq[String]])) => pair.getOrElse("I-PER", Seq.empty[String]))
  val mUDF = udf((pair: (Map[String, Seq[String]])) => pair.getOrElse("I-MISC", Seq.empty[String]))
  val gUDF = udf((pair: (Map[String, Seq[String]])) => pair.getOrElse("I-ORG", Seq.empty[String]))
  val finalDF = backToDf.withColumn("O",oUDF(col("_2")))
    .withColumn("LOC", lUDF(col("_2")))
    .withColumn("PER", pUDF(col("_2")))
    .withColumn("MISC", mUDF(col("_2")))
    .withColumn("ORG", gUDF(col("_2")))
    .drop(col("_2"))
    .withColumnRenamed("_1","text")
  finalDF
}