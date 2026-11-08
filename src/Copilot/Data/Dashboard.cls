/// Dashboard saved by users.
Class Copilot.Data.Dashboard Extends %Persistent
{

Property Name As %String(MAXLEN = 200) [ Required ];

Property Description As %String(MAXLEN = 2000);

/// Auto-refresh interval in seconds (0 = manual).
Property RefreshSeconds As %Integer [ InitialExpression = 15 ];

Property Owner As %String(MAXLEN = 128) [ InitialExpression = {$Username} ];

Property CreatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Property UpdatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

Method ToJSON(withWidgets As %Boolean = 0) As %DynamicObject
{
    Set out = {"id": (..%Id()), "name": (..Name), "description": (..Description), "refreshSeconds": (..RefreshSeconds), "owner": (..Owner), "createdAt": (..CreatedAt), "updatedAt": (..UpdatedAt)}
    If withWidgets {
        Set widgets = []
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Copilot_Data.Widget WHERE Dashboard = ? ORDER BY Seq, ID", ..%Id())
        While rs.%Next() {
            Set w = ##class(Copilot.Data.Widget).%OpenId(rs.%Get("ID"))
            Do:$IsObject(w) widgets.%Push(w.ToJSON())
        }
        Do out.%Set("widgets", widgets)
    } Else {
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Copilot_Data.Widget WHERE Dashboard = ?", ..%Id())
        Do rs.%Next()
        Do out.%Set("widgetCount", +rs.%Get("N"))
    }
    Quit out
}

Storage Default
{
<Data name="DashboardDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Description</Value>
</Value>
<Value name="4">
<Value>RefreshSeconds</Value>
</Value>
<Value name="5">
<Value>Owner</Value>
</Value>
<Value name="6">
<Value>CreatedAt</Value>
</Value>
<Value name="7">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^Copilot.Data.DashboardD</DataLocation>
<DefaultData>DashboardDefaultData</DefaultData>
<IdLocation>^Copilot.Data.DashboardD</IdLocation>
<IndexLocation>^Copilot.Data.DashboardI</IndexLocation>
<StreamLocation>^Copilot.Data.DashboardS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
