/// History of questions and queries (audit and reuse).
Class Copilot.Data.QueryLog Extends %Persistent
{

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property Username As %String(MAXLEN = 128) [ InitialExpression = {$Username} ];

/// ask | agent | fix | run
Property Kind As %String(MAXLEN = 20);

Property Question As %String(MAXLEN = 4000);

Property SQLText As %String(MAXLEN = 32000) [ SqlFieldName = SQLText ];

/// ok | error | message
Property Status As %String(MAXLEN = 20);

Property Attempts As %Integer;

Property RowCount As %Integer;

Property ElapsedMs As %Integer;

Property Error As %String(MAXLEN = 4000);

Index CreatedAtIdx On CreatedAt;

ClassMethod Record(kind As %String, question As %String, sql As %String, status As %String, attempts As %Integer = 1, rowCount As %Integer = 0, elapsedMs As %Integer = 0, error As %String = "")
{
    Try {
        Set log = ..%New()
        Set log.Kind = kind
        Set log.Question = $Extract(question, 1, 4000)
        Set log.SQLText = $Extract(sql, 1, 32000)
        Set log.Status = status
        Set log.Attempts = attempts
        Set log.RowCount = rowCount
        Set log.ElapsedMs = elapsedMs
        Set log.Error = $Extract(error, 1, 4000)
        Do log.%Save()
    } Catch {
    }
}

Storage Default
{
<Data name="QueryLogDefaultData">
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
<Value>Kind</Value>
</Value>
<Value name="5">
<Value>Question</Value>
</Value>
<Value name="6">
<Value>SQLText</Value>
</Value>
<Value name="7">
<Value>Status</Value>
</Value>
<Value name="8">
<Value>Attempts</Value>
</Value>
<Value name="9">
<Value>RowCount</Value>
</Value>
<Value name="10">
<Value>ElapsedMs</Value>
</Value>
<Value name="11">
<Value>Error</Value>
</Value>
</Data>
<DataLocation>^Copilot.Data.QueryLogD</DataLocation>
<DefaultData>QueryLogDefaultData</DefaultData>
<IdLocation>^Copilot.Data.QueryLogD</IdLocation>
<IndexLocation>^Copilot.Data.QueryLogI</IndexLocation>
<StreamLocation>^Copilot.Data.QueryLogS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
