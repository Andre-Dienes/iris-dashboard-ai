/// Scheduled (or on-demand) report of a subscription.
Class Copilot.Interop.Msg.ReportRequest Extends Ens.Request
{

Property SubscriptionId As %String(MAXLEN = 50);

Property Name As %String(MAXLEN = 200);

Property Question As %String(MAXLEN = 4000);

Property SQL As %String(MAXLEN = "");

Property Lang As %String(MAXLEN = 5);

/// Alert when the first numeric value is below this
Property AlertMin As %String(MAXLEN = 50);

/// Alert when the first numeric value is above this
Property AlertMax As %String(MAXLEN = 50);

/// Optional URL notified with the report
Property Webhook As %String(MAXLEN = 1000);

Property Owner As %String(MAXLEN = 128);

/// schedule | manual
Property Trigger As %String(MAXLEN = 20);

/// Set by the Report Process
Property IsAlert As %Boolean [ InitialExpression = 0 ];

}
