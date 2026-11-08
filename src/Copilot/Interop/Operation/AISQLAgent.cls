/// AI SQL Agent - business operation that turns a question into IRIS SQL with the LLM managed by
/// AI Hub (%AI.Provider). Retries arrive with the previous answer and the feedback (IRIS error,
/// empty result), so the self-correction loop is visible in the message trace.
Class Copilot.Interop.Operation.AISQLAgent Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.GenerateSQLRequest">
    <Method>Generate</Method>
  </MapItem>
</MapItems>
}

Method Generate(request As Copilot.Interop.Msg.GenerateSQLRequest, Output response As Copilot.Interop.Msg.GenerateSQLResponse) As %Status
{
    Set sc = $$$OK
    Try {
        Do ##class(Copilot.Core.Config).SetLang(request.Lang)
        // the LLM call runs at the top of a fresh process (see Copilot.Core.Isolate)
        Set text = ##class(Copilot.Core.Isolate).Call("Copilot.AI.SQLAssistant", "GenerateStep", 300,
            request.Question, request.Catalog, request.History, request.PreviousAnswer, request.Feedback)
        Set answer = ##class(Copilot.Core.LLM).ParseJSON(text)
        Set response = ##class(Copilot.Interop.Msg.GenerateSQLResponse).%New()
        Set response.AnswerJSON = $Select(answer.%Size():answer.%ToJSON(), 1:text)
        Set response.SQL = ##class(Copilot.Core.SQL).Normalize(answer.%Get("sql"))
        Set response.IsMessage = (response.SQL="") && (answer.%Get("message")'="")
        Set response.Model = ##class(Copilot.Core.Config).Model()
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

}
