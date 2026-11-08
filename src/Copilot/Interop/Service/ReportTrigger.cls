/// Copilot Report Trigger - adapterless business service used by the portal ("Run now") to start a
/// Report workflow on demand.
Class Copilot.Interop.Service.ReportTrigger Extends Ens.BusinessService
{

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Copilot Report Process" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As Copilot.Interop.Msg.ReportRequest, Output pOutput As %RegisteredObject) As %Status
{
    Set sc = ..SendRequestAsync(..TargetConfigName, pInput)
    Set pOutput = {"sessionId": (..%SessionId)}
    Quit sc
}

}
