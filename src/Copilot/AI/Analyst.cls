/// Autonomous Data Analyst - a declarative InterSystems IRIS AI Hub %AI.Agent.
///   TOOLSETS : Copilot.AI.Tools (the LLM decides which tools to call)
///   Sessions : persistent %AI.Agent.Session objects; the conversation continues through sessionId
///
///   Set json = ##class(Copilot.AI.Analyst).ConverseJSON("Which branches grew the most this year?", "")
Class Copilot.AI.Analyst Extends %AI.Agent
{

Parameter TOOLSETS = "Copilot.AI.Tools";

XData INSTRUCTIONS [ MimeType = text/markdown ]
{
# IRIS Data Analyst

You are a data analyst who helps business users understand the data stored in InterSystems IRIS.

## How to work
1. The first message contains the BUSINESS GLOSSARY (official, mandatory definitions of terms such as revenue
   and periods) and the full catalog (tables, columns, descriptions and `->` relationships).
   Read the column descriptions: they explain how to compute metrics (e.g. margin, revenue).
2. Map every term in the question to the right column (e.g. "product category" is not "sales channel").
   When in doubt use **DescribeTable**; to discover the values of a column, query it with **RunQuery**.
3. Use **RunQuery** with SELECT in the IRIS dialect: `SELECT TOP n` (never LIMIT), `YEAR()`, `MONTH()`,
   `TO_CHAR(CAST(d AS DATE),'YYYY-MM')`, `DATEADD('dd',n,d)`, `DATEDIFF('dd',a,b)`; in GROUP BY repeat the full expression;
   when grouping text use `%EXACT(col)` in SELECT and GROUP BY.
   Use TOP only for rankings; filter periods by date. Show names (JOIN master data), not bare IDs.
4. If a query fails, read the error, fix it and try again.
5. Run as many queries as you need to answer well, combining tables with JOINs.
6. Prefer ONE final query that returns everything ready (names, values and the calculation, e.g. growth %)
   instead of computing by hand from several queries.

## Mandatory rule: never answer from the wrong source
Every message states the data sources (schemas) in scope. If the question refers to a system, application or
dataset (e.g. "helpdesk", "CRM", "telephony") that is not in those sources, do NOT answer with data from another
source, even if it looks similar. Reply briefly that this data is not in the selected sources and tell the user
which schema to select in the **Sources** selector at the top of the portal (you may call ListSchemas to find its
name, but never mention tool names to the user). State in your answer which tables you used.

## Mandatory rule: names, not codes
The user is a business person and does not know codes. Every entity (branch, salesperson, customer, product,
category...) must appear by NAME, obtained by joining its master-data table (e.g. `JOIN Core.Branch b ON b.BranchID = o.BranchID`
and `%EXACT(b.Name) AS Branch`). Never show a column with IDs only.

## Answer
- Answer in the language required by the LANGUAGE/IDIOMA rule of the message (default: English), in markdown, objectively and directly.
- Do not narrate what you are going to do ("I will calculate...", "let's see...") and do not use LaTeX formulas: deliver the result.
- Start with the answer in one sentence, then a short table (at most 10 rows; highlight the key one) and a practical conclusion.
- Format numbers according to the language rule (en-US: $1,234,567.89 and 12.3%; pt-BR: US$ 1.234.567,89 e 12,3%).
- Never invent numbers: use only what the tools returned **in this turn**. Never repeat numbers or SQL from
  previous answers of the conversation: run the queries again with RunQuery (earlier answers may have used the
  wrong source or old data).
- At the end, show the main SQL query used in a ```sql block.
}

Method %OnNew(provider As %AI.Provider = "") As %Status
{
    Set sc = $$$OK
    Try {
        If '$IsObject(provider) {
            Set provider = ##class(%AI.Provider).Create(##class(Copilot.Core.Config).Provider(), ##class(Copilot.Core.Config).ProviderSettings())
        }
        Set sc = ##super(provider)
        Set ..Model = ##class(Copilot.Core.Config).Get("LLM_AGENT_MODEL", ##class(Copilot.Core.Config).Model())
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

/// Runs one conversation turn (always call it through Copilot.Core.Isolate).
/// Returns JSON {"text","sessionId","sqls":[...]}.
ClassMethod ConverseJSON(message As %String, sessionId As %String = "", schemas As %String = "") As %String
{
    If '##class(Copilot.Core.Config).IsConfigured() {
        Quit {"text": (##class(Copilot.Core.Config).T("O Analista precisa de um LLM configurado no AI Hub (defina LLM_API_KEY no .env).", "The Analyst needs an LLM configured in AI Hub (set LLM_API_KEY in .env).")), "sessionId": "", "sqls": []}.%ToJSON()
    }
    Kill %CopilotAgentSQL
    Set start = $ZHorolog
    Set agent = ..%New()
    Set session = ""
    // a conversation is bound to the sources it started with: different sources (or an old conversation
    // without a recorded scope) start a new conversation with the right catalog
    Set scopeKey = $ZConvert(schemas, "U")
    If (sessionId'="") && ($Get(^Copilot.AgentScope(sessionId), $Char(0))'=scopeKey) {
        Set sessionId = ""
    }
    Set:sessionId'="" session = ##class(%AI.Agent.Session).%OpenId(sessionId)
    If $IsObject(session) {
        $$$ThrowOnError(agent.%InitWithSession(session))
    } Else {
        $$$ThrowOnError(agent.%Init())
        Set session = agent.CreateSession()
    }
    // the sources in scope are restated on every turn (the user may change them during the conversation)
    Set scope = "DATA SOURCES IN SCOPE: "_$Select(schemas'="":schemas, 1:"all visible schemas")_$Char(10)
    Set prompt = scope_##class(Copilot.Core.Config).LanguageRule()_$Char(10,10)_message
    If sessionId="" {
        // new conversation: hand over the whole catalog at once (fewer tool round-trips and fewer mapping mistakes)
        Set prompt = scope_"Available data catalog:"_$Char(10)_##class(Copilot.Core.Schema).SchemaText(schemas, 1, 1, message)_$Char(10,10)_##class(Copilot.Core.Config).LanguageRule()_$Char(10,10)_"User question: "_message
    }
    If ##class(Copilot.Core.Config).PrivacyMode() {
        Set prompt = prompt_$Char(10,10)_"PRIVACY MODE IS ON: RunQuery only tells you whether a query works, its columns and its row count; the values stay in IRIS and are shown to the user in the portal. "_
            "Build the best final query, explain in plain language what it returns and how to read it, and never state or guess numbers, names or values. Put the final query in a ```sql block."
    }
    Set response = agent.Chat(session, prompt)
    Do session.%Save()
    Set ^Copilot.AgentScope(session.%Id()) = scopeKey
    Set elapsed = ($ZHorolog - start) * 1000 \ 1
    Do ##class(Copilot.Core.LLM).Log("agent", agent.Model, elapsed, response.Usage)
    Set sqls = []
    For i=1:1:+$Get(%CopilotAgentSQL) {
        Do sqls.%Push(%CopilotAgentSQL(i))
    }
    Do ##class(Copilot.Data.QueryLog).Record("agent", message, $Select(sqls.%Size():sqls.%Get(sqls.%Size() - 1), 1:""), "ok", sqls.%Size(), 0, elapsed, "")
    Quit {"text": (response.Content), "sessionId": (session.%Id()), "sqls": (sqls), "elapsedMs": (elapsed), "privacy": (##class(Copilot.Core.Config).PrivacyMode())}.%ToJSON()
}

}
