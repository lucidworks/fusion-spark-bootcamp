import java.io.Serializable
import java.net.URI
import java.util.Locale

import com.lucidworks.spark.util.SolrSupport
import org.apache.solr.common.SolrInputDocument
import org.apache.spark.{SparkConf, SparkContext}
import org.apache.spark.input.PortableDataStream
import org.joda.time.DateTimeZone
import org.joda.time.format.DateTimeFormat
import org.joda.time.format.DateTimeFormatterBuilder
import org.joda.time.format.ISODateTimeFormat
import org.joda.time.format.{DateTimeFormat, DateTimeFormatterBuilder, ISODateTimeFormat}

import collection.mutable.ListBuffer
import collection.JavaConversions._
import scala.io.Source
import scala.util.control.NonFatal

/**
 * Converts 3-letter time zone IDs to IDs that Joda-Time understands, parses dates using
 * a set of date formats known to be present in the 20 newsgroups data, then converts them
 * to ISO8601 format.
 */
object DateConverter extends Serializable {
  // Map of time zone abbreviations to time zone IDs, from <http://www.timeanddate.com/time/zones/>,
  // <http://www.worldtimezone.com>, and Joda-Time v2.2 DateTimeZone.getAvailableIds()
  val ZoneMap = Map("+3000" -> "Europe/Moscow", // 19 Apr 93 16:15:19 +3000 <- invalid offset, should be +0300
    "ACST" -> "Australia/Adelaide", "BST" -> "Europe/London", "CDT" -> "America/Chicago",
    "CET" -> "Europe/Brussels", "CST" -> "America/Chicago", "ECT" -> "America/Guayaquil",
    "EDT" -> "America/New_York", "EST" -> "America/New_York", "GMT" -> "Etc/GMT",
    "GMT+12" -> "Etc/GMT+12", "IDT" -> "Asia/Jerusalem", "KST" -> "Asia/Seoul",
    "MDT" -> "America/Denver", "MET" -> "Europe/Berlin", "MEZ" -> "Europe/Berlin",
    "MST" -> "America/Denver", "NZDT" -> "Pacific/Auckland", "NZST" -> "Pacific/Auckland",
    "PDT" -> "America/Los_Angeles", "PST" -> "America/Los_Angeles", "TUR" -> "Asia/Istanbul",
    "UT" -> "Etc/UTC", "UTC" -> "Etc/UTC")
    .map(e => e._1 -> DateTimeZone.forID(e._2))
  // Below can't be triple quoted; interpolated raw strings and escapes don't mix: https://issues.scala-lang.org/browse/SI-6476
  val ZonesRegex = s"\\s+\\(?((?i)${ZoneMap.keys.map(z => s"\\Q$z\\E").mkString("|")})\\)?$$".r
  val DateParsers = Array("dd MMM yy",
    "dd MMM yy HH:mm",
    "dd MMM yy HH:mm Z",  // Z is for offsets, e.g. +0200, -0400
    "dd MMM yy HH:mm:ss",
    "dd MMM yy HH:mm:ss Z",
    "MM/dd/yy",
    "MMM dd, yy",
    "yyyy-MM-dd HH:mm:ss",
    "MMM dd HH:mm:ss yy").map(DateTimeFormat.forPattern(_).getParser)
  val Formatter = new DateTimeFormatterBuilder().append(null, DateParsers).toFormatter.withPivotYear(1970).withLocale(Locale.ENGLISH)
  val MultiSpaceRegex = """\s{2,}""".r
  val TrailingOffsetRegex = """\s*\([-+]\d{4}\)$""".r  // Sun, 18 Apr 93 13:35:23 EDT(-0400)
  val DayOfWeekPattern = "(?i:Sun|Mon|Tue(?:s)?|Wed(?:nes)?|Thu(?:rs)?|Fri|Sat(?:ur)?)(?i:day)?"
  val DowRegex = s"$DayOfWeekPattern,?\\s*|\\s*\\($DayOfWeekPattern\\)$$".r
  def toISO8601(date: String): Option[String] = {
    try {
      var zone = DateTimeZone.UTC
      val dateSingleSpaced = MultiSpaceRegex.replaceAllIn(date, " ")
      val dateNoExtraTrailingOffset = TrailingOffsetRegex.replaceFirstIn(dateSingleSpaced, "")
      val dateNoDow = DowRegex.replaceFirstIn(dateNoExtraTrailingOffset, "")
      val dateNoZone = ZonesRegex.replaceAllIn(dateNoDow, m => {
        zone = ZoneMap(m.group(1).toUpperCase(Locale.ROOT))
        ""}) // remove time zone abbreviations
      Some(Formatter.withZone(zone).parseDateTime(dateNoZone).toString(ISODateTimeFormat.dateTimeNoMillis()))
    } catch {
      case NonFatal(e) => println(s"Failed to parse date '$date': $e")
        None
    }
  }
}

object NewsgroupsIndexer extends Serializable {

  val NonXmlCharsRegex = "[\u0000-\u0008\u000B\u000C\u000E-\u001F]".r
  val NewsgroupHeaderRegex = "^([^: \t]+):[ \t]*(.*)".r
  val NonAlphaNumCharsRegex = "[^_A-Za-z0-9]".r

  def main(args:Array[String]) {
    println("Indexing 20 newsgroups data into Solr ...")

    val path = "/Users/timpotter/dev/lw/projects/fusion-spark-bootcamp/labs/ml20news/20news-18828"
    val collection = "ml20news"
    val batchSize = 1000
    val zkHost = System.getProperty("solr.zkhost")

    sc.hadoopConfiguration.setBoolean("mapreduce.input.fileinputformat.input.dir.recursive", true)
    // Use binaryFiles() because wholeTextFiles() assumes files are UTF-8, but article encoding is Latin-1

    sc.binaryFiles(path).foreachPartition(rows => {
      var numDocs = 0
      val solrServer = SolrSupport.getCachedCloudClient(zkHost)
      val batch = ListBuffer.empty[SolrInputDocument]
      def sendBatch(): Unit = {
        SolrSupport.sendBatchToSolr(solrServer, collection, batch.toList)
        numDocs += batch.size
        batch.clear()
      }
      rows.foreach(row => {  // each row is a Tuple: (path, PortableDataStream)
        val (group, articleNum) = parseFilePath(path, row._1)
        val doc = loadNewsgroupArticle(row._2)
        // Newsgroup name is the parent directory; if this file's path doesn't have a parent directory
        // after removing the source path, use the first listed newsgroup from the article content
        val newsgroup = group.getOrElse(doc.getFieldValues("Newsgroups_ss").head)
        doc.addField("id", s"${newsgroup}_$articleNum")
        doc.addField("newsgroup_s", newsgroup)
        doc.addField("filepath_s", row._1)
        batch += doc
        if (batch.size >= batchSize) sendBatch()
      })
      if (batch.nonEmpty) sendBatch()
    })
  }

  def parseFilePath(basePath: String, filePath: String): Tuple2[Option[String],String] = {
    val segments = new URI(basePath).relativize(new URI(filePath)).getPath.split('/').reverse
    val articleNum = segments(0) // Trailing segment is the filename, which is the article number
    // Parent segment, if there is one, is the identified newsgroup
    val newsgroup = if (segments.length > 1) Some(segments(1)) else None
    (newsgroup, articleNum)
  }

  def loadNewsgroupArticle(stream: PortableDataStream): SolrInputDocument = {
    val doc = new SolrInputDocument
    val inputStream = stream.open
    try {
      var noMoreHeaders = false
      val content = new StringBuilder
      for (line <- Source.fromInputStream(inputStream, "ISO-8859-1").getLines) {
        var cleanedLine = NonXmlCharsRegex.replaceAllIn(line, " ") // (Nonprinting) non-XML chars -> spaces
        if (noMoreHeaders) {
          content.append(cleanedLine).append("\n")
        } else {
          NewsgroupHeaderRegex.findFirstMatchIn(cleanedLine) match {
            case None =>
              noMoreHeaders = true
              content.append(cleanedLine).append("\n")
            case Some(fieldValue) => {
              val field = NonAlphaNumCharsRegex.replaceAllIn(fieldValue.group(1), "_")
              val value = fieldValue.group(2)
              field match {
                case "Message-ID" => doc.addField(s"${field}_s", value.trim)
                case "From" | "Subject" | "Sender" => doc.addField(s"${field}_txt_en", value.trim)
                case "Newsgroups" => value.split(",").map(_.trim).filter(_.length > 0)
                  .foreach(newsgroup => doc.addField(s"${field}_ss", newsgroup))
                case "Date" => // 2 fields: original date text, and reformatted as ISO-8601
                  val trimmedValue = value.trim
                  doc.addField(s"${field}_s", trimmedValue)
                  DateConverter.toISO8601(trimmedValue).foreach(doc.addField(s"${field}_tdt", _))
                case _ => doc.addField(s"${field}_txt", value)
              }
            }
          }
        }
      }
      doc.addField("content_txt_en", content.toString())
    } finally {
      inputStream.close()
    }
    doc
  }
}

NewsgroupsIndexer.main(Array())
System.exit(0)
