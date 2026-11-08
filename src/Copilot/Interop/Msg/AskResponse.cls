/// Result of the Ask workflow: validated SQL and its presentation.
Class Copilot.Interop.Msg.AskResponse Extends Ens.Response
{

/// query | message | error
Property Status As %String(MAXLEN = 20);

Property Title As %String(MAXLEN = 500);

/// Validated read-only SQL
Property SQL As %String(MAXLEN = "");

Property Explanation As %String(MAXLEN = "");

Property ChartJSON As %String(MAXLEN = 4000);

Property ViewName As %String(MAXLEN = 100);

Property SuggestionsJSON As %String(MAXLEN = 4000);

/// Clarification message when no SQL applies
Property Message As %String(MAXLEN = "");

/// Generate/execute attempts (self-correction loop)
Property Attempts As %Integer;

/// Rows returned when validated in the workflow
Property RowCount As %Integer;

Property Error As %String(MAXLEN = "");

Property ElapsedMs As %Integer;

/// Interoperability session (set by the service)
Property SessionId As %Integer [ Transient ];

}
