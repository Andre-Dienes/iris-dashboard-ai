/// Single entry point of the web tier (FastAPI through the IRIS Native API / superserver).
///
///   Dispatch(action, payloadJSON) -> JSON string
///
/// AI actions run in an isolated process (Copilot.Core.Isolate); the others run in the connection
/// process, with the privileges of the IRIS user signed in to the portal.
/// Errors come back as {"error": "message"}.
Class Copilot.API.Facade Extends %RegisteredObject
{

/// Actions that call the LLM.
Parameter AIACTIONS = ",ask,explain,fix,insight,agent,dashboards.generate,suggest,";

ClassMethod Dispatch(action As %String, payload As %String = "{}") As %String
{
    Try {
        Do ##class(Copilot.Core.Config).SetLang($Select(payload["""lang"":""pt""":"pt", payload["""lang"":""en""":"en", 1:""))
        If ..#AIACTIONS[(","_action_",") {
            Set out = ##class(Copilot.Core.Isolate).Call($ClassName(), "Run", 600, action, payload)
        } Else {
            Set out = ..Run(action, payload)
        }
    } Catch ex {
        Set out = {"error": (..Message(ex))}.%ToJSON()
    }
    Quit out
}

ClassMethod Message(ex As %Exception.AbstractException) As %String
{
    Set msg = ex.DisplayString()
    For prefix="ERROR #5001: ","ERROR #5001:" {
        Set msg = $Replace(msg, prefix, "")
    }
    Quit $ZStrip(msg, "<>W")
}

ClassMethod Run(action As %String, payload As %String = "{}") As %String
{
    Set p = ##class(%DynamicObject).%FromJSON($Select(payload="":"{}", 1:payload))
    Do ##class(Copilot.Core.Config).SetLang(p.%Get("lang"))
    Set schemas = ..SchemaList(p.%Get("schemas"))
    Set out = ""

    If action="status" {
        Set out = ..Status()
    } ElseIf action="schemas" {
        Set out = {"schemas": (##class(Copilot.Core.Schema).ListSchemas())}
    } ElseIf action="catalog" {
        Set out = {"tables": (##class(Copilot.Core.Schema).Catalog(schemas))}
    } ElseIf action="catalog.refresh" {
        Do ##class(Copilot.Core.Schema).Refresh()
        Set out = {"ok": 1}
    } ElseIf action="run" {
        Set sql = p.%Get("sql"), start = $ZHorolog
        Try {
            Set out = ##class(Copilot.Core.SQL).Run(sql, $Select(+p.%Get("maxRows")>0:+p.%Get("maxRows"), 1:""))
            Do:'p.%Get("silent") ##class(Copilot.Data.QueryLog).Record("run", "SQL manual", sql, "ok", 1, out.rowCount, out.elapsedMs)
        } Catch ex {
            Set msg = ..Message(ex)
            Do:'p.%Get("silent") ##class(Copilot.Data.QueryLog).Record("run", "SQL manual", sql, "error", 1, 0, 0, msg)
            Set out = {"error": (msg), "sqlError": 1}
        }
    } ElseIf action="ask" {
        // through the Interoperability production when it is running; direct call otherwise
        If ##class(Copilot.Interop.Util).IsRunning() {
            Set out = ..AskViaProduction(p.%Get("question"), schemas, p.%Get("history"))
        } Else {
            Set out = ##class(Copilot.AI.SQLAssistant).Ask(p.%Get("question"), schemas, p.%Get("history"))
        }
    } ElseIf $Piece(action, ".")="interop" {
        Set out = ..Interop($Piece(action, ".", 2), p)
    } ElseIf $Piece(action, ".")="subscriptions" {
        Set out = ..Subscriptions($Piece(action, ".", 2), p)
    } ElseIf action="reports.list" {
        Set list = [], rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 100 ID FROM Copilot_Data.Report ORDER BY ID DESC")
        While rs.%Next() {
            Do list.%Push(##class(Copilot.Data.Report).%OpenId(rs.%Get("ID")).ToJSON(0))
        }
        Set out = {"reports": (list)}
    } ElseIf action="reports.get" {
        Set r = ##class(Copilot.Data.Report).%OpenId(p.%Get("id"))
        Set out = $Select($IsObject(r):r.ToJSON(1), 1:{"error": "Report not found."})
    } ElseIf action="explain" {
        Set out = ##class(Copilot.AI.SQLAssistant).ExplainSQL(p.%Get("sql"), schemas)
    } ElseIf action="fix" {
        Set out = ##class(Copilot.AI.SQLAssistant).FixSQL(p.%Get("sql"), p.%Get("error"), schemas, p.%Get("instruction"))
    } ElseIf action="insight" {
        Set out = ##class(Copilot.AI.SQLAssistant).Insight(p.%Get("question"), p.%Get("sql"), p.%Get("data"))
    } ElseIf action="suggest" {
        Set out = ##class(Copilot.AI.SQLAssistant).SuggestQuestions(schemas)
    } ElseIf action="agent" {
        Set out = ##class(%DynamicObject).%FromJSON(##class(Copilot.AI.Analyst).ConverseJSON(p.%Get("message"), p.%Get("sessionId"), schemas))
    } ElseIf $Piece(action, ".")="dashboards" {
        Set out = ..Dashboards($Piece(action, ".", 2), p, schemas)
    } ElseIf $Piece(action, ".")="widgets" {
        Set out = ..Widgets($Piece(action, ".", 2), p)
    } ElseIf $Piece(action, ".")="views" {
        Set out = ..Views($Piece(action, ".", 2), p)
    } ElseIf action="glossary.list" {
        Set out = {"terms": (##class(Copilot.Data.Glossary).List())}
    } ElseIf action="glossary.save" {
        Set out = ##class(Copilot.Data.Glossary).Save(p)
    } ElseIf action="glossary.delete" {
        $$$ThrowOnError(##class(Copilot.Data.Glossary).%DeleteId(p.%Get("id")))
        Set out = {"ok": 1}
    } ElseIf action="history" {
        Set out = ..History(p)
    } Else {
        Set out = {"error": (##class(Copilot.Core.Config).T("Ação desconhecida: ", "Unknown action: ")_action)}
    }
    Quit $Select($IsObject(out):out.%ToJSON(), 1:out)
}

ClassMethod Status() As %DynamicObject
{
    Set calls = 0, tokens = 0
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N, SUM(PromptTokens + CompletionTokens) AS T FROM Copilot_Data.LLMCall WHERE CreatedAt >= ?", $ZDate($Horolog, 3)_" 00:00:00")
    If rs.%Next() {
        Set calls = +rs.%Get("N"), tokens = +rs.%Get("T")
    }
    Quit {
        "iris": ($ZVersion),
        "namespace": ($Namespace),
        "user": ($Username),
        "llm": {
            "provider": (##class(Copilot.Core.Config).Provider()),
            "model": (##class(Copilot.Core.Config).Model()),
            "configured": (##class(Copilot.Core.Config).IsConfigured()),
            "callsToday": (calls),
            "tokensToday": (tokens)
        },
        "privacyMode": (##class(Copilot.Core.Config).PrivacyMode()),
        "viewSchema": (##class(Copilot.Core.Config).ViewSchema()),
        "maxRows": (##class(Copilot.Core.Config).MaxRows()),
        "simulator": ($Get(^Copilot.Simulator("running"), 0)),
        "interop": ($Select(##class(%Dictionary.CompiledClass).%ExistsId("Ens.Director"):##class(Copilot.Interop.Util).IsRunning(), 1:0))
    }
}

// ---------------------------------------------------------------- interoperability

/// Runs a question through the Ask workflow of the production (Copilot Ask Service).
/// The catalog is built here, in the user's own process (so it only lists what the user may see),
/// and the validated SQL is executed again here, as the user, so IRIS SQL privileges always apply.
ClassMethod AskViaProduction(question As %String, schemas As %String, history As %DynamicArray) As %DynamicObject
{
    Set start = $ZHorolog
    Set req = ##class(Copilot.Interop.Msg.AskRequest).%New()
    Set req.Question = question, req.Schemas = schemas, req.Lang = ##class(Copilot.Core.Config).Lang(), req.Username = $Username
    Set req.Catalog = ##class(Copilot.Core.Schema).SchemaText(schemas)
    Set req.History = $Select($IsObject(history):history.%ToJSON(), 1:"[]")
    $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Copilot Ask Service", .service))
    $$$ThrowOnError(service.ProcessInput(req, .resp))
    Set interop = {"sessionId": (resp.SessionId), "workflow": "Copilot Ask Process"}
    Set suggestions = []
    Try {
        Set suggestions = ##class(%DynamicArray).%FromJSON($Select(resp.SuggestionsJSON="":"[]", 1:resp.SuggestionsJSON))
    } Catch {
    }
    If resp.Status="message" {
        Quit {"type": "message", "message": (resp.Message), "suggestions": (suggestions), "attempts": (resp.Attempts), "elapsedMs": (($ZHorolog - start) * 1000 \ 1), "interop": (interop)}
    }
    Set chart = {}
    Try {
        Set chart = ##class(%DynamicObject).%FromJSON($Select(resp.ChartJSON="":"{}", 1:resp.ChartJSON))
    } Catch {
    }
    Set out = {"type": "query", "title": (resp.Title), "sql": (resp.SQL), "explanation": (resp.Explanation), "chart": (chart),
        "viewName": (resp.ViewName), "suggestions": (suggestions), "attempts": (resp.Attempts), "interop": (interop)}
    If resp.Status="error" {
        Do out.%Set("error", resp.Error)
    } Else {
        Try {
            Do out.%Set("result", ##class(Copilot.Core.SQL).Run(resp.SQL))
        } Catch ex {
            // e.g. the user has no SELECT privilege on a table the workflow could validate
            Do out.%Set("error", ..Message(ex))
        }
    }
    Do out.%Set("elapsedMs", ($ZHorolog - start) * 1000 \ 1)
    Quit out
}

ClassMethod Interop(op As %String, p As %DynamicObject) As %DynamicObject
{
    Quit:op="status" ##class(Copilot.Interop.Util).Status()
    Quit:op="sessions" {"sessions": (##class(Copilot.Interop.Util).Sessions(+p.%Get("limit", 40)))}
    Quit:op="trace" ##class(Copilot.Interop.Util).Trace(+p.%Get("sessionId"))
    If op="start" {
        $$$ThrowOnError(##class(Copilot.Interop.Util).Start())
        Quit ##class(Copilot.Interop.Util).Status()
    }
    Quit {"error": (##class(Copilot.Core.Config).T("Operação inválida: ", "Invalid operation: ")_op)}
}

ClassMethod Subscriptions(op As %String, p As %DynamicObject) As %DynamicObject
{
    If op="list" {
        Set list = [], rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Copilot_Data.Subscription ORDER BY ID DESC")
        While rs.%Next() {
            Do list.%Push(##class(Copilot.Data.Subscription).%OpenId(rs.%Get("ID")).ToJSON())
        }
        Quit {"subscriptions": (list)}
    }
    If op="save" {
        Set s = $Select(p.%Get("id")'="":##class(Copilot.Data.Subscription).%OpenId(p.id), 1:##class(Copilot.Data.Subscription).%New())
        Quit:'$IsObject(s) {"error": "Subscription not found."}
        If p.%IsDefined("sql") {
            // validated as the signed-in user: a user can only schedule queries he/she is allowed to run
            Set sql = ##class(Copilot.Core.SQL).Normalize(p.sql)
            Do ##class(Copilot.Core.SQL).Run(sql, 1)
            Set s.SQLText = sql
        }
        For key="name","question","lang","alertMin","alertMax","webhook" {
            Continue:'p.%IsDefined(key)
            Set prop = $Case(key, "name":"Name", "question":"Question", "lang":"Lang", "alertMin":"AlertMin", "alertMax":"AlertMax", :"Webhook")
            Set $Property(s, prop) = p.%Get(key)
        }
        Set:p.%IsDefined("intervalMinutes") s.IntervalMinutes = +p.intervalMinutes
        Set:p.%IsDefined("active") s.Active = ''p.active
        Set:s.Lang="" s.Lang = ##class(Copilot.Core.Config).Lang()
        $$$ThrowOnError(s.%Save())
        Quit s.ToJSON()
    }
    If op="delete" {
        $$$ThrowOnError(##class(Copilot.Data.Subscription).%DeleteId(p.%Get("id")))
        Quit {"ok": 1}
    }
    If op="run" {
        Set s = ##class(Copilot.Data.Subscription).%OpenId(p.%Get("id"))
        Quit:'$IsObject(s) {"error": "Subscription not found."}
        If '##class(Copilot.Interop.Util).IsRunning() {
            Quit {"error": (##class(Copilot.Core.Config).T("A production de interoperabilidade não está em execução.", "The interoperability production is not running."))}
        }
        $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Copilot Report Trigger", .service))
        $$$ThrowOnError(service.ProcessInput(s.ToReportRequest("manual"), .out))
        Quit out
    }
    Quit {"error": (##class(Copilot.Core.Config).T("Operação inválida: ", "Invalid operation: ")_op)}
}

/// Accepts a JSON list or a comma-separated string.
ClassMethod SchemaList(value) As %String
{
    Quit:'$IsObject(value) $Get(value)
    Set out = "", iter = value.%GetIterator()
    While iter.%GetNext(, .s) {
        Set out = out_$Select(out="":"", 1:",")_s
    }
    Quit out
}

// ---------------------------------------------------------------- dashboards

ClassMethod Dashboards(op As %String, p As %DynamicObject, schemas As %String) As %DynamicObject
{
    If op="list" {
        Set list = [], rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Copilot_Data.Dashboard ORDER BY UpdatedAt DESC")
        While rs.%Next() {
            Do list.%Push(##class(Copilot.Data.Dashboard).%OpenId(rs.%Get("ID")).ToJSON(0))
        }
        Quit {"dashboards": (list)}
    }
    If op="get" {
        Set d = ##class(Copilot.Data.Dashboard).%OpenId(p.%Get("id"))
        Quit:'$IsObject(d) {"error": (##class(Copilot.Core.Config).T("Dashboard não encontrado.", "Dashboard not found."))}
        Quit d.ToJSON(1)
    }
    If op="save" {
        Set d = $Select(p.%Get("id")'="":##class(Copilot.Data.Dashboard).%OpenId(p.id), 1:##class(Copilot.Data.Dashboard).%New())
        Quit:'$IsObject(d) {"error": (##class(Copilot.Core.Config).T("Dashboard não encontrado.", "Dashboard not found."))}
        Set:p.%IsDefined("name") d.Name = p.name
        Set:p.%IsDefined("description") d.Description = p.description
        Set:p.%IsDefined("refreshSeconds") d.RefreshSeconds = +p.refreshSeconds
        Set d.UpdatedAt = $ZDateTime($Horolog, 3)
        $$$ThrowOnError(d.%Save())
        Quit d.ToJSON(1)
    }
    If op="delete" {
        $$$ThrowOnError(##class(Copilot.Data.Dashboard).%DeleteId(p.%Get("id")))
        Quit {"ok": 1}
    }
    If op="generate" {
        Set spec = ##class(Copilot.AI.SQLAssistant).GenerateDashboard(p.%Get("prompt"), schemas)
        Set d = ##class(Copilot.Data.Dashboard).%New()
        Set d.Name = $Extract(spec.name, 1, 200), d.Description = $Extract(spec.%Get("description"), 1, 2000)
        Set d.RefreshSeconds = 15
        $$$ThrowOnError(d.%Save())
        Set seq = 0, iter = spec.widgets.%GetIterator()
        While iter.%GetNext(, .w) {
            Continue:w.%IsDefined("error")
            Set seq = seq + 1
            Do ..SaveWidget({"dashboardId": (d.%Id()), "title": (w.title), "sql": (w.sql), "chart": (w.chart), "width": (w.width), "seq": (seq)})
        }
        Set out = d.ToJSON(1)
        Set skipped = []
        Set iter = spec.widgets.%GetIterator()
        While iter.%GetNext(, .w) {
            Do:w.%IsDefined("error") skipped.%Push({"title": (w.title), "error": (w.error)})
        }
        Do out.%Set("skipped", skipped)
        Quit out
    }
    Quit {"error": (##class(Copilot.Core.Config).T("Operação inválida: ", "Invalid operation: ")_op)}
}

ClassMethod Widgets(op As %String, p As %DynamicObject) As %DynamicObject
{
    If op="save" {
        Quit ..SaveWidget(p)
    }
    If op="delete" {
        $$$ThrowOnError(##class(Copilot.Data.Widget).%DeleteId(p.%Get("id")))
        Quit {"ok": 1}
    }
    If op="reorder" {
        Set iter = p.%Get("ids").%GetIterator()
        While iter.%GetNext(.i, .id) {
            Set w = ##class(Copilot.Data.Widget).%OpenId(id)
            Continue:'$IsObject(w)
            Set w.Seq = i + 1
            Do w.%Save()
        }
        Quit {"ok": 1}
    }
    Quit {"error": (##class(Copilot.Core.Config).T("Operação inválida: ", "Invalid operation: ")_op)}
}

ClassMethod SaveWidget(p As %DynamicObject) As %DynamicObject
{
    Set error = ##class(Copilot.Core.SQL).Validate(p.%Get("sql"))
    Quit:error'="" {"error": (error)}
    If p.%Get("id")'="" {
        Set w = ##class(Copilot.Data.Widget).%OpenId(p.id)
        Quit:'$IsObject(w) {"error": (##class(Copilot.Core.Config).T("Widget não encontrado.", "Widget not found."))}
    } Else {
        Set w = ##class(Copilot.Data.Widget).%New()
        Set d = ##class(Copilot.Data.Dashboard).%OpenId(p.%Get("dashboardId"))
        Quit:'$IsObject(d) {"error": (##class(Copilot.Core.Config).T("Dashboard não encontrado.", "Dashboard not found."))}
        Set w.Dashboard = d
        If p.%Get("seq")="" {
            Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(Seq) AS M FROM Copilot_Data.Widget WHERE Dashboard = ?", d.%Id())
            Do rs.%Next()
            Set w.Seq = rs.%Get("M") + 1
        }
    }
    Set:p.%IsDefined("title") w.Title = $Extract(p.title, 1, 300)
    Set:p.%IsDefined("sql") w.SQLText = ##class(Copilot.Core.SQL).Normalize(p.sql)
    Set:p.%IsDefined("chart") w.ChartJSON = $Select($IsObject(p.chart):p.chart.%ToJSON(), 1:p.chart)
    Set:p.%IsDefined("width") w.Width = $Select(+p.width<1:1, +p.width>4:4, 1:+p.width)
    Set:p.%Get("seq")'="" w.Seq = +p.seq
    $$$ThrowOnError(w.%Save())
    Set d = w.Dashboard, d.UpdatedAt = $ZDateTime($Horolog, 3)
    Do d.%Save()
    Quit w.ToJSON()
}

// ---------------------------------------------------------------- views

ClassMethod Views(op As %String, p As %DynamicObject) As %DynamicObject
{
    Set schema = ##class(Copilot.Core.Config).ViewSchema()
    If op="list" {
        Set list = []
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TABLE_NAME, VIEW_DEFINITION FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME", schema)
        While rs.%Next() {
            Set name = rs.%Get("TABLE_NAME"), def = rs.%Get("VIEW_DEFINITION")
            // drop the leading column list and the internal options IRIS appends
            Set:$Extract($ZStrip(def, "<W"))="(" def = $ZStrip($Piece(def, ")", 2, *), "<WC")
            Set:def["/*#OPTIONS" def = $ZStrip($Piece(def, "/*#OPTIONS", 1), ">WC")
            Do list.%Push({"schema": (schema), "name": (name), "fullName": (schema_"."_name), "definition": (def), "description": ($Get(^Copilot.ViewMeta(name, "description"))), "createdBy": ($Get(^Copilot.ViewMeta(name, "user"))), "createdAt": ($Get(^Copilot.ViewMeta(name, "at")))})
        }
        Quit {"schema": (schema), "views": (list)}
    }
    If op="create" {
        Set name = ##class(Copilot.AI.SQLAssistant).SafeName(p.%Get("name"))
        Quit:name="" {"error": (##class(Copilot.Core.Config).T("Informe um nome válido para a view (letras, números e _).", "Enter a valid view name (letters, digits and _)."))}
        Set sql = ##class(Copilot.Core.SQL).Normalize(p.%Get("sql"))
        Set error = ##class(Copilot.Core.SQL).Validate(sql)
        Quit:error'="" {"error": (error)}
        // IRIS views accept TOP without ORDER BY; ORDER BY without TOP is not allowed.
        Set ddl = "CREATE OR REPLACE VIEW "_schema_"."_name_" AS "_sql
        Set rs = ##class(%SQL.Statement).%ExecDirect(, ddl)
        If rs.%SQLCODE<0 {
            Quit {"error": (##class(Copilot.Core.Config).T("O IRIS recusou a view", "IRIS rejected the view")_" (SQLCODE "_rs.%SQLCODE_"): "_rs.%Message)}
        }
        Set ^Copilot.ViewMeta(name, "description") = p.%Get("description")
        Set ^Copilot.ViewMeta(name, "user") = $Username
        Set ^Copilot.ViewMeta(name, "at") = $ZDateTime($Horolog, 3)
        Quit {"ok": 1, "fullName": (schema_"."_name)}
    }
    If op="drop" {
        Set name = ##class(Copilot.AI.SQLAssistant).SafeName(p.%Get("name"))
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "DROP VIEW "_schema_"."_name)
        Quit:rs.%SQLCODE<0 {"error": ("SQLCODE "_rs.%SQLCODE_": "_rs.%Message)}
        Kill ^Copilot.ViewMeta(name)
        Quit {"ok": 1}
    }
    Quit {"error": (##class(Copilot.Core.Config).T("Operação inválida: ", "Invalid operation: ")_op)}
}

// ---------------------------------------------------------------- history

ClassMethod History(p As %DynamicObject) As %DynamicObject
{
    Set limit = $Select(+p.%Get("limit")>0:+p.%Get("limit"), 1:100)
    Set list = []
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP ? ID, CreatedAt, Username, Kind, Question, SQLText, Status, Attempts, RowCount, ElapsedMs, Error FROM Copilot_Data.QueryLog ORDER BY ID DESC", limit)
    While rs.%Next() {
        Do list.%Push({"id": (rs.%Get("ID")), "createdAt": (rs.%Get("CreatedAt")), "user": (rs.%Get("Username")), "kind": (rs.%Get("Kind")), "question": (rs.%Get("Question")), "sql": (rs.%Get("SQLText")), "status": (rs.%Get("Status")), "attempts": (+rs.%Get("Attempts")), "rowCount": (+rs.%Get("RowCount")), "elapsedMs": (+rs.%Get("ElapsedMs")), "error": (rs.%Get("Error"))})
    }
    Quit {"history": (list)}
}

}
