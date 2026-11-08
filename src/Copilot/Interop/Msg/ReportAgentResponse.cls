/// Narrative written by the AI Report Agent.
Class Copilot.Interop.Msg.ReportAgentResponse Extends Ens.Response
{

Property Narrative As %String(MAXLEN = "");

/// Queries the agent ran through its tools
Property AgentQueries As %Integer;

Property Model As %String(MAXLEN = 100);

}
