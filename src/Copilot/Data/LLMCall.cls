/// Log of every LLM call made through AI Hub (cost and latency observability).
Class Copilot.Data.LLMCall Extends %Persistent
{

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property Username As %String(MAXLEN = 128);

Property Purpose As %String(MAXLEN = 40);

Property Provider As %String(MAXLEN = 40);

Property Model As %String(MAXLEN = 100);

Property ElapsedMs As %Integer;

Property PromptTokens As %Integer;

Property CompletionTokens As %Integer;

Property Error As %String(MAXLEN = 2000);

Index CreatedAtIdx On CreatedAt;

Storage Default
{
<Data name="LLMCallDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>CreatedAt</Value>
</Value>
<Value name="3">
<Value>Username</Value>
</Value>
<Value name="4">
<Value>Purpose</Value>
</Value>
<Value name="5">
<Value>Provider</Value>
</Value>
<Value name="6">
<Value>Model</Value>
</Value>
<Value name="7">
<Value>ElapsedMs</Value>
</Value>
<Value name="8">
<Value>PromptTokens</Value>
</Value>
<Value name="9">
<Value>CompletionTokens</Value>
</Value>
<Value name="10">
<Value>Error</Value>
</Value>
</Data>
<DataLocation>^Copilot.Data.LLMCallD</DataLocation>
<DefaultData>LLMCallDefaultData</DefaultData>
<IdLocation>^Copilot.Data.LLMCallD</IdLocation>
<IndexLocation>^Copilot.Data.LLMCallI</IndexLocation>
<StreamLocation>^Copilot.Data.LLMCallS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
