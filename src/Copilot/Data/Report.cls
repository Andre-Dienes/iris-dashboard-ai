/// Report produced by the Report workflow (also written to disk by the Report Publisher).
Class Copilot.Data.Report Extends %Persistent
{

Property SubscriptionId As %String(MAXLEN = 50);

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property Title As %String(MAXLEN = 500);

Property Markdown As %String(MAXLEN = "");

Property IsAlert As %Boolean [ InitialExpression = 0 ];

/// ok | error
Property Status As %String(MAXLEN = 20);

Property RowCount As %Integer;

Property FilePath As %String(MAXLEN = 1000);

/// Interoperability session that produced the report (message trace).
Property SessionId As %Integer;

Index CreatedAtIdx On CreatedAt;

Method ToJSON(withBody As %Boolean = 0) As %DynamicObject
{
    Set out = {"id": (..%Id()), "subscriptionId": (..SubscriptionId), "createdAt": (..CreatedAt), "title": (..Title), "isAlert": (+..IsAlert),
        "status": (..Status), "rowCount": (+..RowCount), "filePath": (..FilePath), "sessionId": (..SessionId)}
    Do:withBody out.%Set("markdown", ..Markdown)
    Quit out
}

}
