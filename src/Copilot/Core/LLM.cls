/// LLM gateway of the portal, built on InterSystems IRIS AI Hub (%AI.Provider).
///
///   Set text = ##class(Copilot.Core.LLM).Chat([{"role":"user","content":"Hello"}])
///
/// Every call goes through here: provider, model and key are governed by AI Hub/config,
/// never by the user interface. Each call is logged in Copilot.Data.LLMCall.
Class Copilot.Core.LLM Extends %RegisteredObject
{

/// %AI.Provider cached in this process.
ClassMethod GetProvider() As %AI.Provider
{
    Set name = ##class(Copilot.Core.Config).Provider()
    Set version = name_"|"_$Get(^Copilot.Config("_version"))
    If $IsObject($Get(%CopilotProvider)), $Get(%CopilotProviderVersion)=version {
        Quit %CopilotProvider
    }
    If '##class(Copilot.Core.Config).IsConfigured() {
        $$$ThrowStatus($$$ERROR($$$GeneralError, ##class(Copilot.Core.Config).T("LLM não configurado: defina LLM_API_KEY (ou OPENAI_API_KEY) no arquivo .env e reinicie o container.", "LLM not configured: set LLM_API_KEY (or OPENAI_API_KEY) in the .env file and restart the container.")))
    }
    Set %CopilotProvider = ##class(%AI.Provider).Create(name, ##class(Copilot.Core.Config).ProviderSettings())
    Set %CopilotProviderVersion = version
    Quit %CopilotProvider
}

/// Chat with the LLM. messages = [{"role":"system|user|assistant","content":"..."}]
ClassMethod Chat(messages As %DynamicArray, temperature As %Float = 0, purpose As %String = "chat") As %String
{
    Set model = ##class(Copilot.Core.Config).Model()
    Set start = $ZHorolog, content = "", usage = "", error = ""
    Try {
        Set response = ..GetProvider().ChatComplete(model, messages, temperature)
        Set content = response.Content
        Set usage = response.Usage
    } Catch ex {
        Set error = ex.DisplayString()
    }
    Do ..Log(purpose, model, ($ZHorolog - start) * 1000 \ 1, usage, error)
    If error'="" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, ##class(Copilot.Core.Config).T("Falha na chamada ao LLM: ", "LLM call failed: ")_error))
    }
    Quit content
}

/// Shortcut: system prompt + user message.
ClassMethod Complete(systemPrompt As %String, userMessage As %String, temperature As %Float = 0, purpose As %String = "chat") As %String
{
    Set messages = []
    Do:systemPrompt'="" messages.%Push({"role":"system","content":(systemPrompt)})
    Do messages.%Push({"role":"user","content":(userMessage)})
    Quit ..Chat(messages, temperature, purpose)
}

/// Extracts the first JSON object from a model answer (strips ```json fences).
ClassMethod ParseJSON(text As %String) As %DynamicObject
{
    Set clean = $Replace($Replace(text, "```json", ""), "```", "")
    Set start = $Find(clean, "{") - 1
    Set end = $Length(clean) - $Find($Reverse(clean), "}") + 2
    Quit:(start<1)||(end<=start) {}
    Try {
        Set obj = ##class(%DynamicObject).%FromJSON($Extract(clean, start, end))
    } Catch {
        Set obj = {}
    }
    Quit obj
}

ClassMethod Log(purpose As %String, model As %String, elapsedMs As %Integer, usage, error As %String = "")
{
    Try {
        Set log = ##class(Copilot.Data.LLMCall).%New()
        Set log.Purpose = purpose
        Set log.Provider = ##class(Copilot.Core.Config).Provider()
        Set log.Model = model
        Set log.ElapsedMs = elapsedMs
        Set log.Username = $Username
        Set log.Error = $Extract(error, 1, 2000)
        If $IsObject(usage) {
            Set json = ##class(%DynamicObject).%FromJSON(..UsageJSON(usage))
            Set log.PromptTokens = +json.%Get("prompt_tokens", json.%Get("input_tokens"))
            Set log.CompletionTokens = +json.%Get("completion_tokens", json.%Get("output_tokens"))
        }
        Do log.%Save()
    } Catch {
    }
}

/// Usage may be a %DynamicObject or an AI Hub object; normalizes it to JSON.
ClassMethod UsageJSON(usage) As %String
{
    Quit:usage.%IsA("%DynamicAbstractObject") usage.%ToJSON()
    Set out = {}
    For prop="prompt_tokens","completion_tokens","input_tokens","output_tokens","PromptTokens","CompletionTokens","InputTokens","OutputTokens" {
        Try {
            Set v = $Property(usage, prop)
            Do:v'="" out.%Set($ZConvert($Replace($Replace(prop, "Tokens", "_tokens"), "Prompt", "prompt"), "L"), v)
        } Catch {
        }
    }
    Quit out.%ToJSON()
}

}
