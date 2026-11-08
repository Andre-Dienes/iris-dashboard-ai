/// Business glossary: official definitions the AI must follow
/// (e.g. what "revenue" means, which period "last month" is).
/// Injected with priority into every prompt (Copilot.Data.Glossary.PromptText()).
/// Users maintain it in the portal (Catalog page); Seed() loads the demo terms.
Class Copilot.Data.Glossary Extends %Persistent
{

/// Term and synonyms, e.g. "Revenue / sales (faturamento, receita)"
Property Term As %String(MAXLEN = 200) [ Required ];

/// Definition in plain language and/or a SQL fragment.
Property Definition As %String(MAXLEN = 4000) [ Required ];

Property Active As %Boolean [ InitialExpression = 1 ];

Property UpdatedBy As %String(MAXLEN = 128) [ InitialExpression = {$Username} ];

Property UpdatedAt As %TimeStamp [ InitialExpression = {$ZDateTime($Horolog, 3)} ];

/// Text for the prompt ("" when there are no active terms).
ClassMethod PromptText() As %String
{
    Set out = "", nl = $Char(10)
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Term, Definition FROM Copilot_Data.Glossary WHERE Active = 1 ORDER BY ID")
    While rs.%Next() {
        Set out = out_"- "_rs.%Get("Term")_": "_rs.%Get("Definition")_nl
    }
    Quit:out="" ""
    Quit "BUSINESS GLOSSARY (official company definitions - MANDATORY, they take precedence over any assumption of yours):"_nl_out
}

ClassMethod List() As %DynamicArray
{
    Set out = []
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Term, Definition, Active, UpdatedBy, UpdatedAt FROM Copilot_Data.Glossary ORDER BY ID")
    While rs.%Next() {
        Do out.%Push({"id": (rs.%Get("ID")), "term": (rs.%Get("Term")), "definition": (rs.%Get("Definition")), "active": (+rs.%Get("Active")), "updatedBy": (rs.%Get("UpdatedBy")), "updatedAt": (rs.%Get("UpdatedAt"))})
    }
    Quit out
}

ClassMethod Save(p As %DynamicObject) As %DynamicObject
{
    Set g = $Select(p.%Get("id")'="":..%OpenId(p.id), 1:..%New())
    Quit:'$IsObject(g) {"error": (##class(Copilot.Core.Config).T("Termo não encontrado.", "Term not found."))}
    Set:p.%IsDefined("term") g.Term = $ZStrip(p.term, "<>W")
    Set:p.%IsDefined("definition") g.Definition = $ZStrip(p.definition, "<>W")
    Set:p.%IsDefined("active") g.Active = ''p.active
    Set g.UpdatedBy = $Username, g.UpdatedAt = $ZDateTime($Horolog, 3)
    Set sc = g.%Save()
    Quit:$$$ISERR(sc) {"error": ($System.Status.GetErrorText(sc))}
    Quit {"ok": 1, "id": (g.%Id())}
}

/// Glossary terms of the demo dataset (US retail chain). Portuguese synonyms help pt-BR users.
ClassMethod Seed()
{
    Quit:..%ExistsId(1)
    For item = $ListBuild("Revenue / sales / net sales (faturamento, receita, vendas)", "SUM(o.TotalAmount) FROM Sales.SalesOrder o WHERE o.Status <> 'Cancelled' - net order value after discount, in US dollars. Do NOT join Sales.OrderItem to compute revenue (OrderItem.LineTotal is gross, before the order discount, and the join duplicates orders). Do not filter by 'Paid' or 'Delivered'."),
               $ListBuild("Last month (último mês, mês passado)", "Previous full calendar month: o.OrderDate >= DATEADD('mm', -1, DATEADD('dd', 1 - DAY(CURRENT_DATE), CURRENT_DATE)) AND o.OrderDate < DATEADD('dd', 1 - DAY(CURRENT_DATE), CURRENT_DATE). State the month used in the explanation."),
               $ListBuild("This month / month to date (este mês, mês atual)", "From the first day of the current month until now: o.OrderDate >= DATEADD('dd', 1 - DAY(CURRENT_DATE), CURRENT_DATE)."),
               $ListBuild("Last N days / months (últimos N dias / meses)", "Rolling window ending today: o.OrderDate >= DATEADD('dd', -N, CURRENT_DATE) or DATEADD('mm', -N, CURRENT_DATE)."),
               $ListBuild("Average order value / AOV (ticket médio)", "Revenue divided by the number of non-cancelled orders, using Sales.SalesOrder only: ROUND(SUM(o.TotalAmount) / COUNT(*), 2)."),
               $ListBuild("Average revenue per customer (média por cliente)", "Revenue of the period divided by the number of distinct customers who bought in the period, using Sales.SalesOrder only: SUM(o.TotalAmount) / COUNT(DISTINCT o.CustomerID)."),
               $ListBuild("Gross margin (margem bruta)", "SUM(i.LineTotal - i.Quantity * p.UnitCost) from Sales.OrderItem i JOIN Core.Product p, considering only items of non-cancelled orders."),
               $ListBuild("Active customer (cliente ativo)", "Customer with at least one non-cancelled order in the last 90 days."),
               $ListBuild("Cancellation rate (taxa de cancelamento)", "Orders with Status = 'Cancelled' divided by all orders of the period, as a percentage.") {
        Set g = ..%New(), g.Term = $List(item, 1), g.Definition = $List(item, 2), g.UpdatedBy = "setup"
        Do g.%Save()
    }
}

Storage Default
{
<Data name="GlossaryDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Term</Value>
</Value>
<Value name="3">
<Value>Definition</Value>
</Value>
<Value name="4">
<Value>Active</Value>
</Value>
<Value name="5">
<Value>UpdatedBy</Value>
</Value>
<Value name="6">
<Value>UpdatedAt</Value>
</Value>
</Data>
<DataLocation>^Copilot.Data.GlossaryD</DataLocation>
<DefaultData>GlossaryDefaultData</DefaultData>
<IdLocation>^Copilot.Data.GlossaryD</IdLocation>
<IndexLocation>^Copilot.Data.GlossaryI</IndexLocation>
<StreamLocation>^Copilot.Data.GlossaryS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
