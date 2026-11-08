/// Answer of the AI SQL Agent.
Class Copilot.Interop.Msg.GenerateSQLResponse Extends Ens.Response
{

/// Raw JSON answer of the model
Property AnswerJSON As %String(MAXLEN = "");

/// Normalized SQL
Property SQL As %String(MAXLEN = "");

/// 1 = clarification message instead of SQL
Property IsMessage As %Boolean;

Property Model As %String(MAXLEN = 100);

}
