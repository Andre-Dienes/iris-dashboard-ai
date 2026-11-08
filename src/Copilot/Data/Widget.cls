/// Dashboard widget: one SQL query + its chart configuration.
Class Copilot.Data.Widget Extends %Persistent
{

Property Dashboard As Copilot.Data.Dashboard [ Required ];

Property Title As %String(MAXLEN = 300);

Property SQLText As %String(MAXLEN = 32000) [ Required, SqlFieldName = SQLText ];

/// JSON: {"type","x","y":[],"series"}
Property ChartJSON As %String(MAXLEN = 4000);

/// Width on the 4-column grid (1-4).
Property Width As %Integer [ InitialExpression = 2 ];

Property Seq As %Integer [ InitialExpression = 0 ];

Index DashboardIdx On Dashboard;

ForeignKey DashboardFK(Dashboard) References Copilot.Data.Dashboard() [ OnDelete = cascade ];

Method ToJSON() As %DynamicObject
{
    Set chart = {}
    Try {
        Set:..ChartJSON'="" chart = ##class(%DynamicObject).%FromJSON(..ChartJSON)
    } Catch {
    }
    Quit {"id": (..%Id()), "dashboardId": (..Dashboard.%Id()), "title": (..Title), "sql": (..SQLText), "chart": (chart), "width": (..Width), "seq": (..Seq)}
}

Storage Default
{
<Data name="WidgetDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Dashboard</Value>
</Value>
<Value name="3">
<Value>Title</Value>
</Value>
<Value name="4">
<Value>SQLText</Value>
</Value>
<Value name="5">
<Value>ChartJSON</Value>
</Value>
<Value name="6">
<Value>Width</Value>
</Value>
<Value name="7">
<Value>Seq</Value>
</Value>
</Data>
<DataLocation>^Copilot.Data.WidgetD</DataLocation>
<DefaultData>WidgetDefaultData</DefaultData>
<IdLocation>^Copilot.Data.WidgetD</IdLocation>
<IndexLocation>^Copilot.Data.WidgetI</IndexLocation>
<StreamLocation>^Copilot.Data.WidgetS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
