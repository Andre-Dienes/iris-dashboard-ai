/// Natural language -> InterSystems IRIS SQL assistant, powered by the LLM managed by AI Hub.
///
///   Ask()               question -> SQL + chart, executed with self-correction (up to 3 attempts)
///   ExplainSQL()        explains a query in plain language
///   FixSQL()            fixes or refines a query from the IRIS error / a user instruction
///   Insight()           summarizes/analyzes a result
///   GenerateDashboard() dashboard description -> several validated widgets
///   SuggestQuestions()  sample questions generated from the catalog
Class Copilot.AI.SQLAssistant Extends %RegisteredObject
{

Parameter MAXATTEMPTS = 3;

/// InterSystems IRIS SQL dialect rules shared by every prompt.
ClassMethod DialectRules() As %String
{
    Set nl = $Char(10)
    Quit "InterSystems IRIS SQL rules (follow them strictly):"_nl_
        "- Use SELECT TOP n to limit rows. Do NOT use LIMIT, OFFSET or FETCH FIRST."_nl_
        "- Qualify tables with their schema (Schema.Table) and use short aliases in JOINs."_nl_
        "- JOIN on the columns marked with '->' in the catalog (column -> Schema.Table.Column)."_nl_
        "- Dates: YEAR(d), MONTH(d), DAY(d), DATEPART('ww', d), DATEADD('dd', n, d), DATEDIFF('dd', d1, d2), CURRENT_DATE, NOW(), CAST(ts AS DATE)."_nl_
        "- Year-month as text: TO_CHAR(CAST(d AS DATE), 'YYYY-MM') - always CAST to DATE before TO_CHAR on TIMESTAMP columns. Write date literals as 'YYYY-MM-DD'."_nl_
        "- In GROUP BY repeat the full expression (no alias, no column number). ORDER BY may use the alias."_nl_
        "- When grouping by text columns use %EXACT(col) in SELECT and GROUP BY (e.g. SELECT %EXACT(b.Region) AS Region ... GROUP BY %EXACT(b.Region)); otherwise IRIS returns the text in UPPERCASE."_nl_
        "- Concatenate with ||. Case-insensitive text comparison: UPPER(col) = UPPER('x') or col %STARTSWITH 'x'."_nl_
        "- Round amounts with ROUND(x, 2). Percentages: ROUND(100.0 * a / NULLIF(b, 0), 1)."_nl_
        "- Do not use complex window functions, FILTER, ILIKE, QUALIFY, :: casts or backticks (`)."_nl_
        "- Give calculated columns readable aliases (e.g. AS Revenue, AS Month) without spaces or accents."_nl_
        "- Use TOP only for rankings (largest/smallest). To limit periods use a date filter, never TOP (TOP would cut months or series)."_nl_
        "- Show readable names (JOIN the master-data tables) instead of bare codes/IDs."_nl_
        "- Use only tables and columns that exist in the catalog. Never invent names."_nl_
        "- Produce exactly ONE read-only SELECT (or WITH ... SELECT) statement, without semicolons or comments."
}

ClassMethod AskSystemPrompt(schemaText As %String) As %String
{
    Set nl = $Char(10)
    Quit "You are IRIS Data Copilot, an InterSystems IRIS SQL expert who helps business users query data in natural language."_nl_nl_
        ..DialectRules()_nl_nl_
        "Response format: ONLY a valid JSON object, with no text before or after it:"_nl_
        "{"_nl_
        "  ""title"": ""short title of the result"","_nl_
        "  ""sql"": ""SELECT ..."","_nl_
        "  ""explanation"": ""plain explanation (2-4 sentences): what the query does, which tables were joined and the assumptions made - always state the exact period (e.g. October 2026) and the status filters used"","_nl_
        "  ""chart"": {""type"": ""bar|hbar|line|area|pie|doughnut|scatter|kpi|table"", ""x"": ""X axis / category column"", ""y"": [""numeric columns""], ""series"": ""optional series column""},"_nl_
        "  ""viewName"": ""SuggestedViewName"","_nl_
        "  ""suggestions"": [""follow-up question 1"", ""follow-up question 2"", ""follow-up question 3""]"_nl_
        "}"_nl_
        "If the catalog includes a BUSINESS GLOSSARY, apply exactly those definitions to the terms in the question (filters, periods and formulas)."_nl_
        "Important reminder: every text column used in GROUP BY must appear as %EXACT(col) AS Name in SELECT and %EXACT(col) in GROUP BY."_nl_
        "Chart choice: time series -> line or area; comparing categories -> bar (hbar for many labels); "_
        "share of a total with up to 8 slices -> pie/doughnut; a single number -> kpi; detailed listings -> table."_nl_
        "If the question is ambiguous or cannot be answered from the catalog, reply {""message"": ""explanation or clarifying question"", ""suggestions"": [...]}."_nl_
        "Schema and table names identify the source system (e.g. a schema containing 'helpdesk' holds the helpdesk data): when the question names a system, use its tables."_nl_
        "When the question gives no period, do not ask for one: use all available data and say so in the explanation. Ask a clarifying question only when the question is truly ambiguous."_nl_
        "You cannot see the data, only the catalog: never claim that a period or value has no data - write the query and let IRIS return the rows. "_
        "When the question asks for two metrics, return ONE query that answers both (e.g. one row per category plus the per-day average as an extra column)."_nl_
        "In multi-turn conversations the new question may refine the previous query (e.g. 'now by month')."_nl_nl_
        "Available data catalog (TABLE/VIEW, columns, types, PK, '->' relationships and sample values):"_nl_
        schemaText_nl_nl_##class(Copilot.Core.Config).LanguageRule()
}

/// Natural-language question -> {type:"query"|"message", title, sql, explanation, chart, result, ...}
/// history: [{"role":"user|assistant","content":"..."}] with the latest conversation turns.
ClassMethod Ask(question As %String, schemas As %String = "", history As %DynamicArray = "") As %DynamicObject
{
    Set start = $ZHorolog
    Set schemaText = ##class(Copilot.Core.Schema).SchemaText(schemas, 1, 1, question)
    Set messages = [{"role": "system", "content": (..AskSystemPrompt(schemaText))}]
    If $IsObject(history) {
        Set from = $Select(history.%Size() > 8: history.%Size() - 8, 1:0)
        For i=from:1:history.%Size()-1 {
            Set h = history.%Get(i)
            Continue:'$IsObject(h)
            Continue:(h.role'="user")&&(h.role'="assistant")
            Do messages.%Push({"role": (h.role), "content": ($Extract(h.content, 1, 4000))})
        }
    }
    Do messages.%Push({"role": "user", "content": (question)})

    Set answer = {}, result = "", error = "", attempts = 0, sql = ""
    For attempt=1:1:..#MAXATTEMPTS {
        Set attempts = attempt
        Set text = ##class(Copilot.Core.LLM).Chat(messages, 0, "ask")
        Set answer = ##class(Copilot.Core.LLM).ParseJSON(text)
        Set sql = ##class(Copilot.Core.SQL).Normalize(answer.%Get("sql"))
        If sql="" {
            If answer.%Get("message")'="" {
                Set error = ""
                Quit
            }
            Set error = "The answer did not contain a valid JSON sql field."
        } Else {
            Set error = ""
            Try {
                Set result = ##class(Copilot.Core.SQL).Run(sql)
            } Catch ex {
                Set error = $Replace(ex.DisplayString(), "ERROR #5001: ", "")
            }
            If (error=""), (result.rowCount=0), (attempt < ..#MAXATTEMPTS), '$Data(emptyRetry) {
                // no rows: give the model one chance to review filters (wrong literal values are common)
                Set emptyRetry = 1
                Do messages.%Push({"role": "assistant", "content": (text)})
                Do messages.%Push({"role": "user", "content": "The query ran without errors but returned 0 rows. Review filters and literal values using the catalog [values]. If the query is correct and an empty result is expected, return the same JSON. Reply with the JSON only."})
                Set lastGood = {"answer": (answer), "result": (result), "sql": (sql)}
                Continue
            }
        }
        Quit:error=""
        Do messages.%Push({"role": "assistant", "content": (text)})
        Do messages.%Push({"role": "user", "content": ("The query failed in InterSystems IRIS with this error: "_error_$Char(10)_"Fix it following the IRIS dialect rules and reply again with the JSON only.")})
    }
    If (error'=""), $IsObject($Get(lastGood)) {
        // the revision made things worse: keep the previous valid (empty) query
        Set answer = lastGood.answer, result = lastGood.result, sql = lastGood.sql, error = ""
    }

    Set out = {}
    If (sql="") && (answer.%Get("message")'="") {
        Set out = {"type": "message", "message": (answer.message), "suggestions": (..Array(answer.%Get("suggestions")))}
    } Else {
        Set out = {"type": "query", "title": (answer.%Get("title")), "sql": (sql), "explanation": (answer.%Get("explanation")), "chart": (..Object(answer.%Get("chart"))), "viewName": (..SafeName(answer.%Get("viewName"))), "suggestions": (..Array(answer.%Get("suggestions")))}
        If error="" {
            Do out.%Set("result", result)
        } Else {
            Do out.%Set("error", error)
        }
    }
    Do out.%Set("attempts", attempts)
    Do out.%Set("elapsedMs", ($ZHorolog - start) * 1000 \ 1)
    Do ##class(Copilot.Data.QueryLog).Record("ask", question, sql, $Select(error'="":"error", out.type="message":"message", 1:"ok"), attempts, $Select($IsObject(result):result.rowCount, 1:0), out.elapsedMs, error)
    Quit out
}

/// One generation step of the Ask workflow (used by the AI SQL Agent business operation).
/// catalog: context built in the user's own process; history: JSON array of previous turns;
/// previousAnswer + feedback: the rejected attempt and why it was rejected. Returns the raw model answer.
ClassMethod GenerateStep(question As %String, catalog As %String, history As %String = "", previousAnswer As %String = "", feedback As %String = "") As %String
{
    Set messages = [{"role": "system", "content": (..AskSystemPrompt(catalog))}]
    Try {
        Set turns = ##class(%DynamicArray).%FromJSON($Select(history="":"[]", 1:history))
        Set from = $Select(turns.%Size() > 8: turns.%Size() - 8, 1:0)
        For i=from:1:turns.%Size()-1 {
            Set h = turns.%Get(i)
            Continue:'$IsObject(h)
            Continue:(h.role'="user")&&(h.role'="assistant")
            Do messages.%Push({"role": (h.role), "content": ($Extract(h.content, 1, 4000))})
        }
    } Catch {
    }
    Do messages.%Push({"role": "user", "content": (question)})
    If previousAnswer'="" {
        Do messages.%Push({"role": "assistant", "content": (previousAnswer)})
        Do messages.%Push({"role": "user", "content": (feedback)})
    }
    Quit ##class(Copilot.Core.LLM).Chat(messages, 0, "ask")
}

/// Explains a SQL query in plain language (markdown).
ClassMethod ExplainSQL(sql As %String, schemas As %String = "") As %DynamicObject
{
    Set system = "You explain InterSystems IRIS SQL queries to business users. "_
        "Use short markdown: a one-sentence summary, then bullets with the tables used, JOINs, filters, groupings and what each result column means. No unnecessary jargon. "_
        "Describe ONLY what the query text actually does: never assume filters, exclusions or rules that are not written in it. "_
        "If the business glossary defines a rule the query does not apply (e.g. excluding cancelled orders), state that it is NOT applied."_$Char(10)_##class(Copilot.Core.Config).LanguageRule()
    Set user = "Catalog:"_$Char(10)_##class(Copilot.Core.Schema).SchemaText(schemas, 0, 1, sql)_$Char(10,10)_"Query:"_$Char(10)_sql
    Quit {"text": (##class(Copilot.Core.LLM).Complete(system, user, 0, "explain"))}
}

/// Fixes a failing query or applies a user instruction. Returns {sql, explanation, result|error}.
ClassMethod FixSQL(sql As %String, error As %String = "", schemas As %String = "", instruction As %String = "") As %DynamicObject
{
    Set nl = $Char(10)
    Set system = "You fix and refine InterSystems IRIS SQL queries."_nl_nl_..DialectRules()_nl_nl_
        "Reply ONLY with JSON: {""sql"": ""corrected query"", ""explanation"": ""what changed and why""}"_nl_nl_
        "Catalog:"_nl_##class(Copilot.Core.Schema).SchemaText(schemas, 1, 1, sql_" "_instruction)_nl_nl_##class(Copilot.Core.Config).LanguageRule()
    Set user = "Query:"_nl_sql
    Set:error'="" user = user_nl_nl_"Error returned by IRIS:"_nl_error
    Set:instruction'="" user = user_nl_nl_"Change requested by the user:"_nl_instruction
    Set messages = [{"role": "system", "content": (system)}, {"role": "user", "content": (user)}]
    Set out = {}
    For attempt=1:1:2 {
        Set text = ##class(Copilot.Core.LLM).Chat(messages, 0, "fix")
        Set answer = ##class(Copilot.Core.LLM).ParseJSON(text)
        Set fixed = ##class(Copilot.Core.SQL).Normalize(answer.%Get("sql"))
        Set out = {"sql": (fixed), "explanation": (answer.%Get("explanation"))}
        Try {
            Do out.%Set("result", ##class(Copilot.Core.SQL).Run(fixed))
            Set err = ""
        } Catch ex {
            Set err = $Replace(ex.DisplayString(), "ERROR #5001: ", "")
            Do out.%Set("error", err)
        }
        Quit:err=""
        Do messages.%Push({"role": "assistant", "content": (text)})
        Do messages.%Push({"role": "user", "content": ("It still fails: "_err_nl_"Fix it and reply with the JSON only.")})
    }
    Do ##class(Copilot.Data.QueryLog).Record("fix", $Select(instruction'="":instruction, 1:"Fix SQL"), out.sql, $Select(out.%IsDefined("error"):"error", 1:"ok"), 1, $Select(out.%IsDefined("result"):out.result.rowCount, 1:0), 0, out.%Get("error"))
    Quit out
}

/// Analysis of a query result (markdown).
ClassMethod Insight(question As %String, sql As %String, data As %DynamicObject) As %DynamicObject
{
    Set nl = $Char(10)
    Set system = "You are a data analyst. Analyze a query result and write an executive summary in markdown: "_
        "up to 5 bullets with highlights, trends, maximum/minimum values, concentration and one suggested next step. "_
        "Use only the numbers provided; never invent data."_nl_##class(Copilot.Core.Config).LanguageRule()
    If ##class(Copilot.Core.Config).PrivacyMode() {
        // privacy mode: only aggregated numeric statistics go to the model, never rows or text values
        Set summary = ##class(Copilot.Core.SQL).Summary(data)
        Set system = system_nl_"PRIVACY MODE: you only receive column names, the row count and numeric statistics (min, max, average, sum) - no individual rows or text values. "_
            "Analyze what these statistics allow (range, average, spread, totals) and do not name or guess individual records or categories."
        Set user = "Original question: "_question_nl_"SQL: "_sql_nl_"Result summary (JSON):"_nl_summary.%ToJSON()
        Quit {"text": (##class(Copilot.Core.LLM).Complete(system, user, 0.2, "insight")), "privacy": 1}
    }
    // cap the volume sent to the LLM
    Set rows = []
    If $IsObject(data), $IsObject(data.%Get("rows")) {
        For i=0:1:(data.rows.%Size() - 1) {
            Quit:i>=80
            Do rows.%Push(data.rows.%Get(i))
        }
    }
    Set payload = {"columns": ($Select($IsObject(data):data.%Get("columns"), 1:[])), "rows": (rows), "totalRows": ($Select($IsObject(data):data.%Get("rowCount"), 1:0))}
    // totals/averages are computed by IRIS over all rows: the model must quote them instead of doing arithmetic
    Do payload.%Set("numericStatsComputedByIRIS", ##class(Copilot.Core.SQL).NumericStats(data))
    Set system = system_nl_"For any total, sum, average, minimum or maximum over the whole result, quote numericStatsComputedByIRIS exactly; "_
        "never add up or average the rows yourself. Shares (%) may be derived only for a single row, as value / sum; never add several rows or shares together."
    Set user = "Original question: "_question_nl_"SQL: "_sql_nl_"Result (JSON, up to 80 rows):"_nl_payload.%ToJSON()
    Quit {"text": (##class(Copilot.Core.LLM).Complete(system, user, 0.2, "insight"))}
}

/// Builds a dashboard definition from a description. Each widget is executed and, when it fails,
/// fixed once. Returns {name, description, widgets:[{title, sql, chart, width, error?}]}.
ClassMethod GenerateDashboard(prompt As %String, schemas As %String = "") As %DynamicObject
{
    Set nl = $Char(10)
    Set system = "You design analytical dashboards on top of an InterSystems IRIS database."_nl_nl_
        ..DialectRules()_nl_nl_
        "Reply ONLY with JSON:"_nl_
        "{""name"": ""dashboard name"", ""description"": ""purpose"", ""widgets"": ["_nl_
        "  {""title"": ""..."", ""sql"": ""SELECT ..."", ""chart"": {""type"": ""kpi|bar|hbar|line|area|pie|doughnut|table"", ""x"": ""col"", ""y"": [""col""], ""series"": ""optional""}, ""width"": 1}"_nl_
        "]}"_nl_
        "Create 5 to 8 widgets: start with 2 to 4 KPIs (queries returning one row and one number, width 1), then charts (width 2) and at most one table (width 4). "_
        "Widths refer to a 4-column grid. Chart queries should return at most ~30 rows (use TOP)."_nl_nl_
        "Catalog:"_nl_##class(Copilot.Core.Schema).SchemaText(schemas, 1, 1, prompt)_nl_nl_##class(Copilot.Core.Config).LanguageRule()
    Set text = ##class(Copilot.Core.LLM).Complete(system, prompt, 0.2, "dashboard")
    Set spec = ##class(Copilot.Core.LLM).ParseJSON(text)
    Set widgets = []
    Set iter = ..Array(spec.%Get("widgets")).%GetIterator()
    While iter.%GetNext(, .w) {
        Continue:'$IsObject(w)
        Set sql = ##class(Copilot.Core.SQL).Normalize(w.%Get("sql"))
        Set item = {"title": (w.%Get("title")), "sql": (sql), "chart": (..Object(w.%Get("chart"))), "width": ($Select(+w.%Get("width")>0:+w.%Get("width"), 1:2))}
        Set error = ""
        Try {
            Do ##class(Copilot.Core.SQL).Run(sql, 5)
        } Catch ex {
            Set error = $Replace(ex.DisplayString(), "ERROR #5001: ", "")
        }
        If error'="" {
            Try {
                Set fixed = ..FixSQL(sql, error, schemas)
                If 'fixed.%IsDefined("error") {
                    Set item.sql = fixed.sql, error = ""
                }
            } Catch {
            }
        }
        Do:error'="" item.%Set("error", error)
        Do widgets.%Push(item)
    }
    Quit {"name": ($Select(spec.%Get("name")'="":spec.name, 1:##class(Copilot.Core.Config).T("Novo painel", "New dashboard"))), "description": (spec.%Get("description")), "widgets": (widgets)}
}

/// Sample questions generated from the catalog.
ClassMethod SuggestQuestions(schemas As %String = "") As %DynamicObject
{
    Set system = "Suggest 6 short, varied business questions a non-technical user could ask about this data (include at least 2 that require a JOIN and 1 about a trend over time). "_
        "Reply ONLY with JSON: {""questions"": [""...""]}"_$Char(10)_##class(Copilot.Core.Config).LanguageRule()
    Set text = ##class(Copilot.Core.LLM).Complete(system, ##class(Copilot.Core.Schema).SchemaText(schemas, 0), 0.7, "suggest")
    Quit {"questions": (..Array(##class(Copilot.Core.LLM).ParseJSON(text).%Get("questions")))}
}

ClassMethod Array(value) As %DynamicArray
{
    Quit:$IsObject(value)&&value.%IsA("%DynamicArray") value
    Quit []
}

ClassMethod Object(value) As %DynamicObject
{
    Quit:$IsObject(value)&&value.%IsA("%DynamicObject") value
    Quit {}
}

/// Safe SQL identifier (letters, digits and _; starts with a letter). Accents are folded.
ClassMethod SafeName(name As %String) As %String
{
    Set name = $Translate(name, "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ -", "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC__")
    Set out = ""
    For i=1:1:$Length(name) {
        Set c = $Extract(name, i)
        Set:(c?1AN)||(c="_") out = out_c
    }
    Set name = out
    Set:(name'="")&&($Extract(name)'?1A) name = "V_"_name
    Quit $Extract(name, 1, 60)
}

}
