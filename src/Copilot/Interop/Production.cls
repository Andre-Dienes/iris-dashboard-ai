/// IRIS Data Copilot production - AI agents in interoperability workflows.
///
/// Ask workflow (every natural-language question asked in the portal):
///   Copilot Ask Service -> Copilot Ask Process -> AI SQL Agent <-> IRIS SQL Executor -> Audit Log
///
/// Report and alert workflow (scheduled or on demand):
///   Copilot Report Scheduler / Copilot Report Trigger -> Copilot Report Process (BPL)
///     -> IRIS SQL Executor -> AI Report Agent (%AI.Agent) -> Report Publisher (file) -> Webhook Notifier -> Audit Log
Class Copilot.Interop.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Copilot.Interop.Production" TestingEnabled="false" LogGeneralTraceEvents="false">
  <Description>IRIS Data Copilot - AI agents (InterSystems AI Hub) in interoperability workflows: natural language to SQL with self-correction, scheduled AI reports and alerts.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Copilot Ask Service" Category="Ask" ClassName="Copilot.Interop.Service.AskService" PoolSize="0" Enabled="true" Foreground="false" Comment="Entry point of every question asked in the portal" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Copilot Ask Process" Category="Ask" ClassName="Copilot.Interop.Process.AskProcess" PoolSize="2" Enabled="true" Foreground="false" Comment="Self-correction loop between the AI SQL Agent and the IRIS SQL Executor" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="AI SQL Agent" Category="Ask,AI" ClassName="Copilot.Interop.Operation.AISQLAgent" PoolSize="2" Enabled="true" Foreground="false" Comment="LLM via AI Hub (%AI.Provider): question + catalog -> IRIS SQL" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="IRIS SQL Executor" Category="Ask,Report" ClassName="Copilot.Interop.Operation.SQLExecutor" PoolSize="2" Enabled="true" Foreground="false" Comment="Read-only guard and execution" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Copilot Report Scheduler" Category="Report" ClassName="Copilot.Interop.Service.ReportScheduler" PoolSize="1" Enabled="true" Foreground="false" Comment="Starts the reports that are due" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="CallInterval">30</Setting>
  </Item>
  <Item Name="Copilot Report Trigger" Category="Report" ClassName="Copilot.Interop.Service.ReportTrigger" PoolSize="0" Enabled="true" Foreground="false" Comment="Run now (portal)" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Copilot Report Process" Category="Report" ClassName="Copilot.Interop.Process.ReportProcess" PoolSize="1" Enabled="true" Foreground="false" Comment="BPL: data -> alert rule -> AI narrative -> publish -> notify" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="AI Report Agent" Category="Report,AI" ClassName="Copilot.Interop.Operation.AIReportAgent" PoolSize="1" Enabled="true" Foreground="false" Comment="%AI.Agent (Copilot.AI.Analyst) writes the report narrative" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Report Publisher" Category="Report" ClassName="Copilot.Interop.Operation.ReportPublisher" PoolSize="1" Enabled="true" Foreground="false" Comment="Markdown file (File Outbound Adapter) + portal" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/home/irisowner/copilot/reports/</Setting>
    <Setting Target="Adapter" Name="Charset">UTF-8</Setting>
  </Item>
  <Item Name="Webhook Notifier" Category="Report" ClassName="Copilot.Interop.Operation.WebhookNotifier" PoolSize="1" Enabled="true" Foreground="false" Comment="Optional notification (Teams, Slack, automation)" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Audit Log" Category="Ask,Report" ClassName="Copilot.Interop.Operation.AuditLog" PoolSize="1" Enabled="true" Foreground="false" Comment="Audit trail of every AI interaction" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
