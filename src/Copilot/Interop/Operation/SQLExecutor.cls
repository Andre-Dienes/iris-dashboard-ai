/// IRIS SQL Executor - business operation that validates (read-only guard) and runs a query.
/// In the Ask workflow it only validates (ReturnData = 0): the result shown to the user is computed
/// again in the user's own process, so IRIS SQL privileges always apply.
Class Copilot.Interop.Operation.SQLExecutor Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.ExecuteSQLRequest">
    <Method>Execute</Method>
  </MapItem>
</MapItems>
}

Method Execute(request As Copilot.Interop.Msg.ExecuteSQLRequest, Output response As Copilot.Interop.Msg.ExecuteSQLResponse) As %Status
{
    Set response = ##class(Copilot.Interop.Msg.ExecuteSQLResponse).%New()
    Try {
        Set result = ##class(Copilot.Core.SQL).Run(request.SQL, $Select(request.MaxRows>0:request.MaxRows, 1:1000))
        Set response.OK = 1, response.RowCount = result.rowCount, response.ElapsedMs = result.elapsedMs
        // first numeric value of the first row (alert rules)
        If result.rows.%Size() {
            Set row = result.rows.%Get(0)
            For c=0:1:row.%Size()-1 {
                If result.columns.%Get(c).type="number", row.%Get(c)'="" {
                    Set response.FirstNumber = row.%Get(c)
                    Quit
                }
            }
        }
        Set:request.ReturnData response.ResultJSON = result.%ToJSON()
    } Catch ex {
        Set response.OK = 0, response.Error = $Replace(ex.DisplayString(), "ERROR #5001: ", "")
    }
    Quit $$$OK
}

}
