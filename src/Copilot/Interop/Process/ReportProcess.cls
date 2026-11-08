/// Copilot Report Process (BPL) - scheduled report and alert workflow:
///
///   IRIS SQL Executor (current data)
///     -> alert rule (first numeric value vs AlertMin / AlertMax)
///     -> AI Report Agent (%AI.Agent writes the narrative)
///     -> Report Publisher (Markdown file + portal)
///     -> Webhook Notifier (optional, e.g. Teams / Slack)
///     -> Audit Log
Class Copilot.Interop.Process.ReportProcess Extends Ens.BusinessProcessBPL [ ClassType = persistent ]
{

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='Copilot.Interop.Msg.ReportRequest' response='Ens.Response' height='2000' width='2000' >
<context>
<property name='OK' type='%Boolean' initialexpression='0' />
<property name='Error' type='%String' >
<parameters><parameter name='MAXLEN' value='' /></parameters>
</property>
<property name='RowCount' type='%Integer' initialexpression='0' />
<property name='FirstNumber' type='%String' />
<property name='ResultJSON' type='%String' >
<parameters><parameter name='MAXLEN' value='' /></parameters>
</property>
<property name='IsAlert' type='%Boolean' initialexpression='0' />
<property name='AlertRule' type='%String' >
<parameters><parameter name='MAXLEN' value='500' /></parameters>
</property>
<property name='Narrative' type='%String' >
<parameters><parameter name='MAXLEN' value='' /></parameters>
</property>
<property name='Started' type='%String' />
</context>
<sequence xend='200' yend='1200' >
<code name='Start' xpos='200' ypos='150' >
<![CDATA[ set context.Started = $ZHorolog]]>
</code>
<call name='Run report query' target='IRIS SQL Executor' async='0' xpos='200' ypos='250' >
<request type='Copilot.Interop.Msg.ExecuteSQLRequest' >
<assign property="callrequest.SQL" value="request.SQL" action="set" />
<assign property="callrequest.MaxRows" value="200" action="set" />
<assign property="callrequest.ReturnData" value="1" action="set" />
</request>
<response type='Copilot.Interop.Msg.ExecuteSQLResponse' >
<assign property="context.OK" value="callresponse.OK" action="set" />
<assign property="context.Error" value="callresponse.Error" action="set" />
<assign property="context.RowCount" value="callresponse.RowCount" action="set" />
<assign property="context.FirstNumber" value="callresponse.FirstNumber" action="set" />
<assign property="context.ResultJSON" value="callresponse.ResultJSON" action="set" />
</response>
</call>
<if name='Query OK?' condition='context.OK' xpos='200' ypos='350' xend='200' yend='850' >
<true>
<code name='Evaluate alert rule' xpos='335' ypos='500' >
<![CDATA[ set value = context.FirstNumber
 if value'="" {
   if (request.AlertMin'="") && (value < request.AlertMin) { set context.IsAlert = 1, context.AlertRule = value_" < "_request.AlertMin }
   if (request.AlertMax'="") && (value > request.AlertMax) { set context.IsAlert = 1, context.AlertRule = value_" > "_request.AlertMax }
 }]]>
</code>
<call name='AI Report Agent' target='AI Report Agent' async='0' xpos='335' ypos='600' >
<request type='Copilot.Interop.Msg.ReportAgentRequest' >
<assign property="callrequest.Name" value="request.Name" action="set" />
<assign property="callrequest.Question" value="request.Question" action="set" />
<assign property="callrequest.SQL" value="request.SQL" action="set" />
<assign property="callrequest.Lang" value="request.Lang" action="set" />
<assign property="callrequest.RowCount" value="context.RowCount" action="set" />
<assign property="callrequest.IsAlert" value="context.IsAlert" action="set" />
<assign property="callrequest.AlertRule" value="context.AlertRule" action="set" />
</request>
<response type='Copilot.Interop.Msg.ReportAgentResponse' >
<assign property="context.Narrative" value="callresponse.Narrative" action="set" />
</response>
</call>
</true>
</if>
<call name='Publish report' target='Report Publisher' async='0' xpos='200' ypos='950' >
<request type='Copilot.Interop.Msg.PublishRequest' >
<assign property="callrequest.SubscriptionId" value="request.SubscriptionId" action="set" />
<assign property="callrequest.Name" value="request.Name" action="set" />
<assign property="callrequest.Title" value="request.Name" action="set" />
<assign property="callrequest.Narrative" value="context.Narrative" action="set" />
<assign property="callrequest.SQL" value="request.SQL" action="set" />
<assign property="callrequest.ResultJSON" value="context.ResultJSON" action="set" />
<assign property="callrequest.RowCount" value="context.RowCount" action="set" />
<assign property="callrequest.IsAlert" value="context.IsAlert" action="set" />
<assign property="callrequest.Status" value="$Select(context.OK:&quot;ok&quot;,1:&quot;error&quot;)" action="set" />
<assign property="callrequest.Error" value="context.Error" action="set" />
<assign property="callrequest.Lang" value="request.Lang" action="set" />
</request>
<response type='Copilot.Interop.Msg.PublishResponse' />
</call>
<if name='Webhook?' condition='request.Webhook&apos;=""' xpos='200' ypos='1050' xend='200' yend='1150' >
<true>
<call name='Notify webhook' target='Webhook Notifier' async='1' xpos='335' ypos='1100' >
<request type='Copilot.Interop.Msg.WebhookRequest' >
<assign property="callrequest.URL" value="request.Webhook" action="set" />
<assign property="callrequest.Payload" value="##class(Copilot.Data.Subscription).WebhookPayload(request.Name, context.IsAlert, context.AlertRule, context.Narrative, context.RowCount)" action="set" />
</request>
</call>
</true>
</if>
<call name='Audit' target='Audit Log' async='1' xpos='200' ypos='1150' >
<request type='Copilot.Interop.Msg.AuditRequest' >
<assign property="callrequest.Kind" value="&quot;report&quot;" action="set" />
<assign property="callrequest.Question" value="&quot;[&quot;_request.Trigger_&quot;] &quot;_request.Name" action="set" />
<assign property="callrequest.SQL" value="request.SQL" action="set" />
<assign property="callrequest.Status" value="$Select(context.OK:&quot;ok&quot;,1:&quot;error&quot;)" action="set" />
<assign property="callrequest.Attempts" value="1" action="set" />
<assign property="callrequest.RowCount" value="context.RowCount" action="set" />
<assign property="callrequest.ElapsedMs" value="($ZHorolog-context.Started)*1000\1" action="set" />
<assign property="callrequest.Error" value="$Extract(context.Error,1,4000)" action="set" />
<assign property="callrequest.Username" value="request.Owner" action="set" />
</request>
</call>
</sequence>
</process>
}

}
