/// Audit Log - business operation that records every AI interaction in Copilot.Data.QueryLog
/// (question, SQL, attempts, rows, time, error and the IRIS user who asked).
Class Copilot.Interop.Operation.AuditLog Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.AuditRequest">
    <Method>Record</Method>
  </MapItem>
</MapItems>
}

Method Record(request As Copilot.Interop.Msg.AuditRequest, Output response As Ens.Response) As %Status
{
    Set log = ##class(Copilot.Data.QueryLog).%New()
    Set log.Kind = request.Kind
    Set log.Question = request.Question
    Set log.SQLText = $Extract(request.SQL, 1, 32000)
    Set log.Status = request.Status
    Set log.Attempts = request.Attempts
    Set log.RowCount = request.RowCount
    Set log.ElapsedMs = request.ElapsedMs
    Set log.Error = request.Error
    Set:request.Username'="" log.Username = request.Username
    Quit log.%Save()
}

}
