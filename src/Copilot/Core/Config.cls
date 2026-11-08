/// Central configuration of IRIS Data Copilot.
///
/// Every key is resolved in this order:
///   1. ^Copilot.Config(key)       -> ##class(Copilot.Core.Config).Set("LLM_MODEL","gpt-4o")
///   2. OS environment variable    -> docker-compose / .env
///   3. Built-in default
Class Copilot.Core.Config Extends %RegisteredObject
{

Parameter DEFAULTPROVIDER = "openai";

Parameter DEFAULTMODEL = "gpt-4o-mini";

/// SQL schema where the portal creates user views.
Parameter DEFAULTVIEWSCHEMA = "Analytics";

ClassMethod Get(key As %String, default As %String = "") As %String
{
    Set value = $Get(^Copilot.Config(key))
    Quit:value'="" value
    Set env = $System.Util.GetEnviron(key)
    Quit:env'="" env
    Quit default
}

ClassMethod Set(key As %String, value As %String) As %Status
{
    Set ^Copilot.Config(key) = value
    // forces processes that cached the provider to rebuild it
    Set ^Copilot.Config("_version") = $Increment(^Copilot.Config("_version"))
    Quit $$$OK
}

/// AI Hub provider name (%AI.Provider.Create): openai, anthropic, ...
ClassMethod Provider() As %String
{
    Quit $ZConvert(..Get("LLM_PROVIDER", ..#DEFAULTPROVIDER), "L")
}

ClassMethod Model() As %String
{
    Quit ..Get("LLM_MODEL", ..#DEFAULTMODEL)
}

ClassMethod ApiKey() As %String
{
    Set key = ..Get("LLM_API_KEY")
    Quit:key'="" key
    Quit:..Provider()="anthropic" ..Get("ANTHROPIC_API_KEY")
    Quit ..Get("OPENAI_API_KEY")
}

/// Optional base URL (OpenAI-compatible endpoints: Azure, Ollama, vLLM, LM Studio...).
ClassMethod BaseUrl() As %String
{
    Quit ..Get("LLM_BASE_URL")
}

/// Is there an LLM credential (or a local endpoint) configured?
ClassMethod IsConfigured() As %Boolean
{
    Quit (..ApiKey()'="") || (..BaseUrl()'="")
}

/// Settings for %AI.Provider.Create().
ClassMethod ProviderSettings() As %DynamicObject
{
    Set settings = {}
    Do settings.%Set("api_key", $Select(..ApiKey()'="":..ApiKey(), 1:"not-needed"))
    Do:..BaseUrl()'="" settings.%Set("base_url", ..BaseUrl())
    Quit settings
}

ClassMethod ViewSchema() As %String
{
    Quit ..Get("VIEW_SCHEMA", ..#DEFAULTVIEWSCHEMA)
}

/// Maximum number of rows returned to the UI.
ClassMethod MaxRows() As %Integer
{
    Quit +..Get("MAX_ROWS", 1000)
}

/// Maximum size (characters) of the schema context sent to the LLM.
ClassMethod MaxSchemaChars() As %Integer
{
    Quit +..Get("MAX_SCHEMA_CHARS", 40000)
}

/// Language code of the current request: "en" or "pt".
/// Set per request in %CopilotLang (Copilot.API.Facade); default COPILOT_LANG (en).
ClassMethod Lang() As %String
{
    Set lang = $ZConvert($Extract($Get(%CopilotLang), 1, 2), "L")
    Set:lang="" lang = $ZConvert($Extract(..Get("COPILOT_LANG", "en"), 1, 2), "L")
    Quit $Select(lang="pt":"pt", 1:"en")
}

/// lang "" = use the default (COPILOT_LANG).
ClassMethod SetLang(lang As %String)
{
    Set lang = $ZConvert($Extract(lang, 1, 2), "L")
    If (lang'="pt") && (lang'="en") {
        Kill %CopilotLang
        Quit
    }
    Set %CopilotLang = lang
}

/// Name of the language the assistant answers in.
ClassMethod Language() As %String
{
    Quit $Select(..Lang()="pt":"português do Brasil", 1:"English (United States)")
}

/// Final rule of every prompt: language of the text, number format and column aliases.
ClassMethod LanguageRule() As %String
{
    If ..Lang()="pt" {
        Quit "IDIOMA (obrigatório): o usuário fala português do Brasil. Escreva TODO texto para o usuário (title, explanation, suggestions, mensagens, análises, títulos de widgets, nome do painel) em português do Brasil, "_
            "mesmo que o catálogo, o glossário e os dados estejam em inglês. Traduza os termos de negócio com naturalidade (Revenue = Faturamento, Branch = Filial, Order = Pedido, Customer = Cliente, Salesperson = Vendedor, Region = Região, Channel = Canal). "_
            "Use aliases de coluna em português, sem acentos (ex.: AS Faturamento, AS Mes, AS Filial). Formate números no padrão brasileiro (os valores estão em dólares): US$ 1.234.567,89 e 12,3%; meses como outubro/2026."
    }
    Quit "LANGUAGE (mandatory): write ALL user-facing text (title, explanation, suggestions, messages, analysis, widget titles, dashboard name) in English (United States). "_
        "Use English column aliases in SQL (e.g. AS Revenue, AS Month, AS Branch). Format numbers in US style: $1,234,567.89 and 12.3%; months as October 2026."
}

/// Text in the language of the current request.
ClassMethod T(pt As %String, en As %String) As %String
{
    Quit $Select(..Lang()="pt":pt, 1:en)
}

}
