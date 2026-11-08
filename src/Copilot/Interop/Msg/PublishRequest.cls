/// Report to publish (file + portal) by the Report Publisher.
Class Copilot.Interop.Msg.PublishRequest Extends Ens.Request
{

Property SubscriptionId As %String(MAXLEN = 50);

Property Name As %String(MAXLEN = 200);

Property Title As %String(MAXLEN = 500);

Property Narrative As %String(MAXLEN = "");

Property SQL As %String(MAXLEN = "");

Property ResultJSON As %String(MAXLEN = "");

Property RowCount As %Integer;

Property IsAlert As %Boolean;

/// ok | error
Property Status As %String(MAXLEN = 20);

Property Error As %String(MAXLEN = "");

Property Lang As %String(MAXLEN = 5);

}
