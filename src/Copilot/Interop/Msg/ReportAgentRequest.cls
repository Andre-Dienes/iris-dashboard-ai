/// Request to the AI Report Agent (%AI.Agent) to write the report narrative.
Class Copilot.Interop.Msg.ReportAgentRequest Extends Ens.Request
{

Property Name As %String(MAXLEN = 200);

Property Question As %String(MAXLEN = 4000);

Property SQL As %String(MAXLEN = "");

Property Lang As %String(MAXLEN = 5);

Property RowCount As %Integer;

Property IsAlert As %Boolean;

Property AlertRule As %String(MAXLEN = 500);

}
