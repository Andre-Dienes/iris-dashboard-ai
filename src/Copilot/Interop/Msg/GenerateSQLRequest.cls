/// Request to the AI SQL Agent: question + catalog (+ feedback from the previous attempt).
Class Copilot.Interop.Msg.GenerateSQLRequest Extends Ens.Request
{

Property Question As %String(MAXLEN = 4000);

Property Catalog As %String(MAXLEN = "");

Property History As %String(MAXLEN = "");

Property Lang As %String(MAXLEN = 5);

Property Attempt As %Integer;

/// Previous model answer (JSON) when retrying
Property PreviousAnswer As %String(MAXLEN = "");

/// Why the previous attempt was rejected (IRIS error, empty result...)
Property Feedback As %String(MAXLEN = "");

}
