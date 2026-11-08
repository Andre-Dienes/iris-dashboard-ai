/// Copilot Ask Service - entry point of the Ask workflow. The portal (Copilot.API.Facade) calls it
/// through Ens.Director.CreateBusinessService for every natural-language question.
Class Copilot.Interop.Service.AskService Extends Ens.BusinessService
{

/// Business process that orchestrates the AI SQL Agent and the IRIS SQL Executor.
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Copilot Ask Process" ];

/// Seconds to wait for the workflow.
Property Timeout As %Integer [ InitialExpression = 600 ];

Parameter SETTINGS = "TargetConfigName:Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},Timeout:Basic";

Method OnProcessInput(pInput As Copilot.Interop.Msg.AskRequest, Output pOutput As Copilot.Interop.Msg.AskResponse) As %Status
{
    Set sc = ..SendRequestSync(..TargetConfigName, pInput, .pOutput, ..Timeout)
    Set:$IsObject($Get(pOutput)) pOutput.SessionId = ..%SessionId
    Quit sc
}

}
