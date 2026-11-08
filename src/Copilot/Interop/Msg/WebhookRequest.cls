/// Notification posted to an external webhook.
Class Copilot.Interop.Msg.WebhookRequest Extends Ens.Request
{

Property URL As %String(MAXLEN = 1000);

/// JSON body
Property Payload As %String(MAXLEN = "");

}
