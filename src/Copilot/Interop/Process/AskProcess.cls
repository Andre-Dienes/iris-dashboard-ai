/// Copilot Ask Process - orchestrates the AI SQL Agent and the IRIS SQL Executor in a
/// self-correction loop (up to 3 attempts):
///
///   AI SQL Agent ──SQL──► IRIS SQL Executor ──error / 0 rows──► AI SQL Agent (with feedback) ...
///
/// then records the interaction in the Audit Log. Every attempt is a message in the trace.
Class Copilot.Interop.Process.AskProcess Extends Ens.BusinessProcess [ ClassType = persistent ]
{

Parameter MAXATTEMPTS = 3;

Method OnRequest(request As Copilot.Interop.Msg.AskRequest, Output response As Copilot.Interop.Msg.AskResponse) As %Status
{
    Set start = $ZHorolog
    Set response = ##class(Copilot.Interop.Msg.AskResponse).%New()
    Set previous = "", feedback = "", emptyRetried = 0, final = "", good = "", rows = 0, goodRows = 0, error = "", attempts = 0
    Try {
        For attempt=1:1:..#MAXATTEMPTS {
            Set attempts = attempt
            // 1. AI SQL Agent: question (+ feedback) -> SQL
            Set gen = ##class(Copilot.Interop.Msg.GenerateSQLRequest).%New()
            Set gen.Question = request.Question, gen.Catalog = request.Catalog, gen.History = request.History
            Set gen.Lang = request.Lang, gen.Attempt = attempt, gen.PreviousAnswer = previous, gen.Feedback = feedback
            $$$ThrowOnError(..SendRequestSync("AI SQL Agent", gen, .genResp, 300))
            Set previous = genResp.AnswerJSON
            If genResp.IsMessage {
                Set final = genResp, error = ""
                Quit
            }
            If genResp.SQL="" {
                Set error = "The answer did not contain a valid JSON sql field."
                Set feedback = error_" Reply with the JSON only."
                Continue
            }
            // 2. IRIS SQL Executor: validate (read-only guard) and run
            Set exec = ##class(Copilot.Interop.Msg.ExecuteSQLRequest).%New()
            Set exec.SQL = genResp.SQL, exec.MaxRows = ##class(Copilot.Core.Config).MaxRows(), exec.ReturnData = 0
            $$$ThrowOnError(..SendRequestSync("IRIS SQL Executor", exec, .execResp, 300))
            If execResp.OK {
                If (execResp.RowCount=0) && 'emptyRetried && (attempt < ..#MAXATTEMPTS) {
                    // no rows: one chance to review filters and literal values
                    Set emptyRetried = 1, good = genResp, goodRows = 0
                    Set feedback = "The query ran without errors but returned 0 rows. Review filters and literal values using the catalog [values]. If the query is correct and an empty result is expected, return the same JSON. Reply with the JSON only."
                    Continue
                }
                Set final = genResp, rows = execResp.RowCount, error = ""
                Quit
            }
            Set error = execResp.Error
            Set feedback = "The query failed in InterSystems IRIS with this error: "_error_$Char(10)_"Fix it following the IRIS dialect rules and reply again with the JSON only."
        }
        If '$IsObject(final), $IsObject(good) {
            // the revision made things worse: keep the previous valid (empty) query
            Set final = good, rows = goodRows, error = ""
        }
        Do ..FillResponse(response, final, error, rows, attempts)
    } Catch ex {
        Set response.Status = "error", response.Error = ex.DisplayString(), response.Attempts = attempts
    }
    Set response.ElapsedMs = ($ZHorolog - start) * 1000 \ 1

    // 3. Audit Log (fire-and-forget)
    Set audit = ##class(Copilot.Interop.Msg.AuditRequest).%New()
    Set audit.Kind = "ask", audit.Question = request.Question, audit.SQL = response.SQL, audit.Username = request.Username
    Set audit.Status = $Select(response.Status="query":"ok", 1:response.Status)
    Set audit.Attempts = response.Attempts, audit.RowCount = response.RowCount, audit.ElapsedMs = response.ElapsedMs
    Set audit.Error = $Extract(response.Error, 1, 4000)
    Do ..SendRequestAsync("Audit Log", audit, 0)
    Quit $$$OK
}

Method FillResponse(response As Copilot.Interop.Msg.AskResponse, final, error As %String, rows As %Integer, attempts As %Integer)
{
    Set response.Attempts = attempts, response.RowCount = rows
    If '$IsObject(final) {
        Set response.Status = "error", response.Error = error
        Quit
    }
    Set answer = ##class(Copilot.Core.LLM).ParseJSON(final.AnswerJSON)
    If final.IsMessage {
        Set response.Status = "message", response.Message = answer.%Get("message")
    } Else {
        Set response.Status = "query", response.SQL = final.SQL
        Set response.Title = $Extract(answer.%Get("title"), 1, 500)
        Set response.Explanation = answer.%Get("explanation")
        Set response.ChartJSON = $Select($IsObject(answer.%Get("chart")):answer.chart.%ToJSON(), 1:"{}")
        Set response.ViewName = ##class(Copilot.AI.SQLAssistant).SafeName(answer.%Get("viewName"))
    }
    Set response.SuggestionsJSON = $Select($IsObject(answer.%Get("suggestions")):answer.suggestions.%ToJSON(), 1:"[]")
}

}
