/// AI Report Agent - business operation that asks the autonomous %AI.Agent (Copilot.AI.Analyst)
/// to write the narrative of a scheduled report. The agent explores the data with its own tools
/// (respecting PRIVACY_MODE) and returns an executive summary.
Class Copilot.Interop.Operation.AIReportAgent Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.ReportAgentRequest">
    <Method>WriteNarrative</Method>
  </MapItem>
</MapItems>
}

Method WriteNarrative(request As Copilot.Interop.Msg.ReportAgentRequest, Output response As Copilot.Interop.Msg.ReportAgentResponse) As %Status
{
    Set sc = $$$OK
    Try {
        Do ##class(Copilot.Core.Config).SetLang(request.Lang)
        Set nl = $Char(10)
        Set prompt = "Write the scheduled report """_request.Name_"""."_nl_
            "Business question: "_request.Question_nl_
            "Report query (already validated, "_request.RowCount_" rows):"_nl_request.SQL_nl_
            $Select(request.IsAlert:"ALERT: the alert rule was triggered ("_request.AlertRule_"). Start the report by stating the alert clearly."_nl, 1:"")_
            "Run the report query (or a variation of it) with RunQuery to read the current numbers, then write: "_
            "one title line starting with '# ', 3 to 5 bullets with the key facts, and a one-sentence recommendation. Do not include the SQL."
        Set json = ##class(Copilot.Core.Isolate).Call("Copilot.AI.Analyst", "ConverseJSON", 600, prompt, "", "")
        Set out = ##class(%DynamicObject).%FromJSON(json)
        Set response = ##class(Copilot.Interop.Msg.ReportAgentResponse).%New()
        Set response.Narrative = out.%Get("text")
        Set response.AgentQueries = $Select($IsObject(out.%Get("sqls")):out.sqls.%Size(), 1:0)
        Set response.Model = ##class(Copilot.Core.Config).Get("LLM_AGENT_MODEL", ##class(Copilot.Core.Config).Model())
    } Catch ex {
        // the workflow goes on: the report is still published with the data computed by IRIS
        Set response = ##class(Copilot.Interop.Msg.ReportAgentResponse).%New()
        Set response.Narrative = ##class(Copilot.Core.Config).T("_Narrativa da IA indisponível: ", "_AI narrative unavailable: ")_$Replace(ex.DisplayString(), "ERROR #5001: ", "")_"_"
        $$$LOGWARNING("AI Report Agent: "_ex.DisplayString())
    }
    Quit sc
}

}
