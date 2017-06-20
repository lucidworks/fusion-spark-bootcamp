import java.util.{TimeZone, Calendar}

import com.lucidworks.spark.fusion.FusionPipelineClient

import scala.collection.JavaConversions._
import scala.collection.mutable.ListBuffer

object LoadEventsimIntoFusion extends java.io.Serializable {

  val fusionEndpoints = "http://localhost:8765"
  val pipelinePath = "/api/v1/index-pipelines/eventsim-default/collections/eventsim/index"
  val fusionBatchSize = 1000

  def main(args:Array[String]) {

    spark.read.json("control.data.json").foreachPartition(rows => {
      val fusion: FusionPipelineClient = new FusionPipelineClient(fusionEndpoints)

      val batch = new ListBuffer[Map[String,_]]()
      rows.foreach(next => {
        var userId : String = ""
        var sessionId : String = ""
        var ts : Long = 0

        val fields = new ListBuffer[Map[String,_]]()
        for (c <- 0 to next.length-1) {
          val obj = next.get(c)
          if (obj != null) {
            var colValue = obj
            val fieldName = next.schema.fieldNames(c)
            if ("ts" == fieldName || "registration" == fieldName) {
              ts = obj.asInstanceOf[Long]
              val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
              cal.setTimeInMillis(ts)
              colValue = cal.getTime.toInstant.toString
            } else if ("userId" == fieldName) {
              userId = obj.toString
            } else if ("sessionId" == fieldName) {
              sessionId = obj.toString
            }
            fields += Map("name" -> fieldName, "value" -> colValue)
          }
        }

        batch += Map("id" -> s"$userId-$sessionId-$ts", "fields" -> fields)

        if (batch.size == fusionBatchSize) {
          fusion.postBatchToPipeline(pipelinePath, bufferAsJavaList(batch))
          batch.clear
        }
      })

      // post the final batch if any left over
      if (!batch.isEmpty) {
        fusion.postBatchToPipeline(pipelinePath, bufferAsJavaList(batch))
        batch.clear
      }
    })
  }
}
LoadEventsimIntoFusion.main(Array())
System.exit(0)

