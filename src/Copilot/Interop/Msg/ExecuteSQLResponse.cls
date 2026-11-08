/// Outcome of a query execution.
Class Copilot.Interop.Msg.ExecuteSQLResponse Extends Ens.Response
{

Property OK As %Boolean;

Property RowCount As %Integer;

Property Error As %String(MAXLEN = "");

Property ElapsedMs As %Integer;

/// First numeric value of the first row (used by alert rules)
Property FirstNumber As %String(MAXLEN = 50);

/// Result rows (only when ReturnData = 1)
Property ResultJSON As %String(MAXLEN = "");

}
