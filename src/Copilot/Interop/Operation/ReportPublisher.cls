/// Report Publisher - business operation that writes each report as a Markdown file through the
/// File Outbound Adapter (FilePath setting) and stores it in Copilot.Data.Report for the portal.
Class Copilot.Interop.Operation.ReportPublisher Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.File.OutboundAdapter";

Parameter INVOCATION = "Queue";

Property Adapter As EnsLib.File.OutboundAdapter;

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.PublishRequest">
    <Method>Publish</Method>
  </MapItem>
</MapItems>
}

Method Publish(request As Copilot.Interop.Msg.PublishRequest, Output response As Copilot.Interop.Msg.PublishResponse) As %Status
{
    Set sc = $$$OK
    Try {
        Do ##class(Copilot.Core.Config).SetLang(request.Lang)
        Set markdown = ..BuildMarkdown(request)
        Set fileName = "report-"_request.SubscriptionId_"-"_$Translate($ZDateTime($Horolog, 8), ": ", "-_")_".md"
        Set stream = ##class(%Stream.GlobalCharacter).%New()
        // the adapter encodes the file (Charset = UTF-8 in the production settings)
        Do stream.Write(markdown)
        $$$ThrowOnError(..Adapter.PutStream(fileName, stream))

        Set report = ##class(Copilot.Data.Report).%New()
        Set report.SubscriptionId = request.SubscriptionId
        Set report.Title = $Extract(request.Title, 1, 500)
        Set report.Markdown = markdown
        Set report.IsAlert = request.IsAlert
        Set report.Status = request.Status
        Set report.RowCount = request.RowCount
        Set report.FilePath = ..Adapter.FilePath_fileName
        Set report.SessionId = ..%SessionId
        $$$ThrowOnError(report.%Save())

        Set response = ##class(Copilot.Interop.Msg.PublishResponse).%New()
        Set response.ReportId = report.%Id(), response.FilePath = report.FilePath
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

/// Report = AI narrative + data table computed by IRIS (the numbers never depend on the LLM).
Method BuildMarkdown(request As Copilot.Interop.Msg.PublishRequest) As %String
{
    Set nl = $Char(10), T = "Copilot.Core.Config"
    Set md = $Select(request.IsAlert:"> ⚠️ "_$ClassMethod(T, "T", "ALERTA", "ALERT")_nl_nl, 1:"")
    If request.Status="error" {
        Set md = md_"# "_request.Name_nl_nl_$ClassMethod(T, "T", "A consulta do relatório falhou: ", "The report query failed: ")_request.Error_nl
        Quit md
    }
    Set narrative = request.Narrative
    Set:$Extract($ZStrip(narrative, "<W"))'="#" md = md_"# "_request.Title_nl_nl
    Set md = md_narrative_nl_nl_"## "_$ClassMethod(T, "T", "Dados", "Data")_nl_nl
    Try {
        Set result = ##class(%DynamicObject).%FromJSON(request.ResultJSON)
        Set header = "|", sep = "|"
        Set iter = result.columns.%GetIterator()
        While iter.%GetNext(, .col) {
            Set header = header_" "_col.name_" |", sep = sep_" --- |"
        }
        Set md = md_header_nl_sep_nl
        Set iter = result.rows.%GetIterator(), n = 0
        While iter.%GetNext(, .row) {
            Set n = n + 1
            Quit:n>50
            Set line = "|", cells = row.%GetIterator()
            While cells.%GetNext(, .v) {
                Set line = line_" "_$Translate(v, "|"_$Char(10,13), "/  ")_" |"
            }
            Set md = md_line_nl
        }
        Set:request.RowCount>50 md = md_nl_"_"_$ClassMethod(T, "T", "Mostrando 50 de ", "Showing 50 of ")_request.RowCount_"_"_nl
    } Catch {
    }
    Set md = md_nl_"---"_nl_"_IRIS Data Copilot · "_$ZDateTime($Horolog, 3)_" · "_$ClassMethod(T, "T", "sessão de interoperabilidade ", "interoperability session ")_..%SessionId_"_"_nl
    Quit md
}

}
