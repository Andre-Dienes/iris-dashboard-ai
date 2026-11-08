/// Audit record of an AI interaction (fire-and-forget).
Class Copilot.Interop.Msg.AuditRequest Extends Ens.Request
{

/// ask | report | agent
Property Kind As %String(MAXLEN = 20);

Property Question As %String(MAXLEN = 4000);

Property SQL As %String(MAXLEN = "");

Property Status As %String(MAXLEN = 20);

Property Attempts As %Integer;

Property RowCount As %Integer;

Property ElapsedMs As %Integer;

Property Error As %String(MAXLEN = 4000);

Property Username As %String(MAXLEN = 128);

}
