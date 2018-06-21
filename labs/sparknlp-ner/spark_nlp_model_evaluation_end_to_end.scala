import com.johnsnowlabs.nlp.annotator._
import com.johnsnowlabs.nlp.annotators.ner.NerConverter
import com.johnsnowlabs.nlp.base._
import com.johnsnowlabs.util.Benchmark
import org.apache.spark.ml.Pipeline
import org.apache.spark.sql.SparkSession
import spark.implicits._
import scala.io.Source

/*
 * This script is not executed by any jobs at the moment. It is provided to
 * show how to evaluate some accuracy metrics for the johnsnow library on
 * NER tagging tasks.
 *
 * Two versions of the test are provided:
 * - conll2003,
 * - conll2002
 *
 * IMPORTANT:
 *
 * - Downlod the respective `INPUT_SENTENCES_FILE` and `INPUT_TAGS_FILE` from
 * the provided S3 buckets, and store it locally. Then please provide the
 * full paths to these files in the code_snippet below.
 *
 * - Then start the spark-shell with a dependency to the johnsnow:1.5.4, and run the scripts.
 *
 * TODO: It is possible to use the java-aws-sdk library to stream the data directly, but it's a work in progress.
 */
var TEST = "conll2003"

var INPUT_SENTENCES_FILE = ""
var INPUT_TAGS_FILE = ""
var sepG = ""
var lastColG = ""

if(TEST == "conll2003") {
  sepG = " "
  lastColG = "_c3"
  INPUT_SENTENCES_FILE = "/Users/apiltamang/nlp_benchmarking/datasets/conll2003/scala-format/test/testb-sentences.txt"   //containing sentences to be NER Tagged
  INPUT_TAGS_FILE = "/Users/apiltamang/nlp_benchmarking/datasets/conll2003/scala-format/test/eng.testb.txt"        //containing standardized applied NER Tags
} else if (TEST == "conll2002") {
  sepG = ","
  lastColG = "_c2"
  INPUT_SENTENCES_FILE = "/Users/apiltamang/nlp_benchmarking/datasets/conll2002/scala_format/conll2002_sentences.txt"   //containing sentences to be NER Tagged
  INPUT_TAGS_FILE = "/Users/apiltamang/nlp_benchmarking/datasets/conll2002/conll2002_tokens_tags.csv"        //containing standardized applied NER Tags
}

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

val pipeline = new Pipeline().setStages(Array(document, token, normalizer, ner, nerConverter, finisher))
val data = spark.read.option("sep","\t").csv(INPUT_SENTENCES_FILE)
val intext = data.withColumnRenamed("_c0","text")
val result = pipeline.fit(Seq.empty[String].toDS.toDF("text")).transform(intext)
var all_ner = result.select("finished_ner")

def splitTokens(str: String): List[String] = {
  val foo = str.split("@")
  return foo.toList
}

var ner_by_tokens = all_ner.map(s => splitTokens(s.getAs[String](0))).flatMap(identity)

def splitWords(str: String): (String,String) = {
  // str: word->London#result->LOC
  val xs = str.split("#")
  var first = ""
  var secnd = ""
  try{
    first = xs(0).substring(6)
    secnd = xs(1).substring(8)
  } catch {
    case e: Exception => {
      first = "ERROR: "+str
      secnd = "ERROR: "+str
    }
  }
  (first, secnd)
}


var dfGold = spark.read.format("csv").option("header",false).option("delimiter", sepG).load(INPUT_TAGS_FILE)

var dG = dfGold.select("_c0", lastColG).withColumnRenamed("_c0","word").withColumnRenamed(lastColG,"tag")
val dP = ner_by_tokens.map(s => splitWords(s)).withColumnRenamed("_1","word").withColumnRenamed("_2","tag")

var mapping = Map("I-org" -> "I-ORG", "B-org" -> "I-ORG", "I-ORG" -> "I-ORG", "B-ORG" -> "I-ORG",
  "I-per" -> "I-PER", "B-per" -> "I-PER", "I-PER" -> "I-PER", "B-PER" -> "I-PER",
  "I-gpe" -> "I-LOC", "B-gpe" -> "I-LOC", "I-geo" -> "I-LOC", "B-geo" -> "I-LOC", "I-LOC" -> "I-LOC", "B-LOC" -> "I-LOC",
  "B-tim" -> "I-MISC", "I-tim" -> "I-MISC", "B-art" -> "I-MISC", "I-art" -> "I-MISC", "B-nat" -> "I-MISC", "I-nat" -> "I-MISC",
  "B-eve" -> "I-MISC", "I-eve" -> "I-MISC", "I-MISC" -> "I-MISC", "B-MISC" -> "I-MISC", "O" -> "O")

var mapFunc: String => String = mapping(_)
var mapUdf = udf(mapFunc)

var dGM = dG.withColumn("tagMapped", mapUdf($"tag")).select("word","tagMapped").withColumnRenamed("tagMapped","tag")

def evaluateMetrics(tagI: String): (Float, Float, Float) = {

  // dGM: dataFrame with gold standard tags
  // dP: dataFrame with predicted tags

  var relevant = dGM.filter($"tag"===tagI).distinct
  var retrieved = dP.filter($"tag"===tagI).distinct
  var common = retrieved.intersect(relevant)

  var commCnt = common.count
  var retrCnt = retrieved.count
  var relvCnt = relevant.count

  var precision = commCnt.toFloat/retrCnt
  var recall = commCnt.toFloat/relvCnt
  var fScore = 2 * precision * recall / (precision+recall)

  (precision, recall, fScore)
}

var foo = evaluateMetrics("I-PER")
// var bar = evaluateMetrics("I-MISC")
// var jez = evaluateMetrics("I-LOC")
// var buz = evaluateMetrics("I-ORG")
// var duh = evaluateMetrics("O")
