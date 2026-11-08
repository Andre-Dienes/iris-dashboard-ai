/// Request to run a read-only query on IRIS.
Class Copilot.Interop.Msg.ExecuteSQLRequest Extends Ens.Request
{

Property SQL As %String(MAXLEN = "");

Property MaxRows As %Integer [ InitialExpression = 1000 ];

/// 0 = validation only (rows are not returned)
Property ReturnData As %Boolean [ InitialExpression = 0 ];

}
