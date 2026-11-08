/// Natural-language question sent by the portal to the Ask workflow.
Class Copilot.Interop.Msg.AskRequest Extends Ens.Request
{

/// Question typed by the user
Property Question As %String(MAXLEN = 4000);

/// Schemas selected by the user (comma separated)
Property Schemas As %String(MAXLEN = 2000);

/// Catalog context built in the user's own process (respects the user's privileges)
Property Catalog As %String(MAXLEN = "");

/// Previous conversation turns (JSON array)
Property History As %String(MAXLEN = "");

/// Answer language: en | pt
Property Lang As %String(MAXLEN = 5);

/// IRIS user who asked
Property Username As %String(MAXLEN = 128);

}
