/// Copilot Report Scheduler - polling business service (Ens.InboundAdapter, CallInterval) that
/// finds report subscriptions that are due and starts one Report workflow for each of them.
Class Copilot.Interop.Service.ReportScheduler Extends Ens.BusinessService
{

Parameter ADAPTER = "Ens.InboundAdapter";

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Copilot Report Process" ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Set sc = $$$OK
    Try {
        Set now = $ZDateTime($Horolog, 3)
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Copilot_Data.Subscription WHERE Active = 1 AND (NextRunAt IS NULL OR NextRunAt <= ?)", now)
        While rs.%Next() {
            Set sub = ##class(Copilot.Data.Subscription).%OpenId(rs.%Get("ID"))
            Continue:'$IsObject(sub)
            Do sub.ScheduleNext()
            $$$ThrowOnError(..SendRequestAsync(..TargetConfigName, sub.ToReportRequest("schedule")))
        }
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

}
