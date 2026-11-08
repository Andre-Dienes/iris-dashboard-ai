/// Report subscription: a saved question/query that the Report workflow runs on a schedule,
/// with an optional alert rule and webhook.
Class Copilot.Data.Subscription Extends %Persistent
{

Property Name As %String(MAXLEN = 200) [ Required ];

Property Question As %String(MAXLEN = 4000);

Property SQLText As %String(MAXLEN = 32000) [ Required, SqlFieldName = SQLText ];

/// Language of the report narrative (en | pt).
Property Lang As %String(MAXLEN = 5) [ InitialExpression = "en" ];

/// Minutes between runs.
Property IntervalMinutes As %Integer [ InitialExpression = 60 ];

/// Alert when the first numeric value of the result is below this value (optional).
Property AlertMin As %String(MAXLEN = 50);

/// Alert when the first numeric value of the result is above this value (optional).
Property AlertMax As %String(MAXLEN = 50);

/// Optional webhook notified with every report (e.g. Teams / Slack incoming webhook).
Property Webhook As %String(MAXLEN = 1000);

Property Owner As %String(MAXLEN = 128) [ InitialExpression = {$Username} ];

Property Active As %Boolean [ InitialExpression = 1 ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property LastRunAt As %TimeStamp;

Property NextRunAt As %TimeStamp;

Index NextRunIdx On (Active, NextRunAt);

Method ScheduleNext()
{
    Set ..LastRunAt = $ZDateTime($Horolog, 3)
    Set secs = ($Horolog * 86400) + $Piece($Horolog, ",", 2) + ($Select(..IntervalMinutes>0:..IntervalMinutes, 1:60) * 60)
    Set ..NextRunAt = $ZDateTime((secs \ 86400)_","_(secs # 86400), 3)
    Do ..%Save()
}

Method ToReportRequest(trigger As %String = "schedule") As Copilot.Interop.Msg.ReportRequest
{
    Set req = ##class(Copilot.Interop.Msg.ReportRequest).%New()
    Set req.SubscriptionId = ..%Id(), req.Name = ..Name, req.Question = ..Question, req.SQL = ..SQLText
    Set req.Lang = ..Lang, req.AlertMin = ..AlertMin, req.AlertMax = ..AlertMax, req.Webhook = ..Webhook
    Set req.Owner = ..Owner, req.Trigger = trigger
    Quit req
}

Method ToJSON() As %DynamicObject
{
    Quit {"id": (..%Id()), "name": (..Name), "question": (..Question), "sql": (..SQLText), "lang": (..Lang),
        "intervalMinutes": (..IntervalMinutes), "alertMin": (..AlertMin), "alertMax": (..AlertMax),
        "webhook": (..Webhook), "owner": (..Owner), "active": (+..Active), "lastRunAt": (..LastRunAt), "nextRunAt": (..NextRunAt)}
}

/// JSON body posted by the Webhook Notifier ("text" works with Teams/Slack incoming webhooks).
ClassMethod WebhookPayload(name As %String, isAlert As %Boolean, rule As %String, narrative As %String, rows As %Integer) As %String
{
    Set text = $Select(isAlert:"ALERT ("_rule_") - ", 1:"")_name_$Char(10,10)_$Extract(narrative, 1, 3000)
    Quit {"source": "IRIS Data Copilot", "report": (name), "alert": (''isAlert), "rule": (rule), "rows": (rows), "text": (text)}.%ToJSON()
}

}
