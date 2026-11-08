/// Installation and startup.
///   Build()    - during the image build (iris/iris.script): demo dataset, sample dashboard, glossary
///                (skipped when COPILOT_DEMO=0 - use your own tables instead)
///   Startup()  - on every container start (iris/entrypoint.sh): MCP tools and sales simulator
///   Install()  - installs the Copilot in an EXISTING IRIS namespace (no Docker, no demo data)
Class Copilot.Setup.Installer Extends %RegisteredObject
{

ClassMethod Build() As %Status
{
    Set sc = $$$OK
    Try {
        If ##class(Copilot.Core.Config).Get("COPILOT_DEMO", "1")'="0" {
            $$$ThrowOnError(##class(Copilot.Setup.DemoData).Load())
            Do ..SeedDashboard()
            Do ##class(Copilot.Data.Glossary).Seed()
            Write "IRIS Data Copilot installed with the demo dataset.",!
        } Else {
            Write "IRIS Data Copilot installed without demo data (COPILOT_DEMO=0).",!
        }
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Install error: ",ex.DisplayString(),!
    }
    Quit sc
}

ClassMethod Startup() As %Status
{
    Set sc = $$$OK
    Try {
        Write "LLM provider: ",##class(Copilot.Core.Config).Provider()," / ",##class(Copilot.Core.Config).Model(),
            "  configured=",##class(Copilot.Core.Config).IsConfigured(),!
        Do ..RegisterTools()
        Do ##class(Copilot.Setup.Simulator).Start()
        Write "IRIS Data Copilot ready.",!
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Startup error: ",ex.DisplayString(),!
    }
    Quit sc
}

/// Installs the Copilot classes into the CURRENT namespace of an existing IRIS instance.
///   zn "MYAPP"
///   do $system.OBJ.LoadDir("/path/to/repo/src", "ck", , 1)
///   do ##class(Copilot.Setup.Installer).Install()
/// Then point the web portal to this namespace (IRIS_NAMESPACE) and configure the LLM key.
ClassMethod Install(withDemo As %Boolean = 0) As %Status
{
    Set sc = $$$OK
    Try {
        If withDemo {
            $$$ThrowOnError(##class(Copilot.Setup.DemoData).Load())
            Do ..SeedDashboard()
            Do ##class(Copilot.Data.Glossary).Seed()
        }
        Do ##class(Copilot.Core.Schema).Refresh()
        Do ..RegisterTools()
        Write "IRIS Data Copilot installed in namespace ",$Namespace,".",!
        Write "Visible schemas: ",##class(Copilot.Core.Schema).ListSchemas().%ToJSON(),!
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Install error: ",ex.DisplayString(),!
    }
    Quit sc
}

/// Loads the MCP tool catalog of /mcp/copilot (when AI Hub MCP is available).
ClassMethod RegisterTools() As %Status
{
    Set sc = $$$OK
    Try {
        Set mgr = ##class(%AI.ToolMgr).GetOrCreate("/mcp/copilot", .isNew)
        Do mgr.Cleanup()
        Set mgr = ##class(%AI.ToolMgr).GetOrCreate("/mcp/copilot", .isNew)
        Set sc = ##class(%AI.MCP.Service).LoadToolSetsToManager(mgr, "Copilot.AI.Tools")
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Write "MCP tools: ",$Select($$$ISOK(sc):"ok", 1:$System.Status.GetErrorText(sc)),!
    Quit sc
}

/// Sample dashboard, ready for the demo.
ClassMethod SeedDashboard()
{
    Quit:##class(Copilot.Data.Dashboard).%ExistsId(1)
    Set d = ##class(Copilot.Data.Dashboard).%New()
    Set d.Name = "Live sales", d.Description = "Sample dashboard refreshed every 10 seconds (the simulator keeps inserting orders).", d.RefreshSeconds = 10
    $$$ThrowOnError(d.%Save())
    Set id = d.%Id()
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Revenue today ($)", "width": 1, "chart": {"type": "kpi"},
        "sql": "SELECT SUM(TotalAmount) AS Revenue FROM Sales.SalesOrder WHERE Status <> 'Cancelled' AND CAST(OrderDate AS DATE) = CURRENT_DATE"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Orders today", "width": 1, "chart": {"type": "kpi"},
        "sql": "SELECT COUNT(*) AS Orders FROM Sales.SalesOrder WHERE CAST(OrderDate AS DATE) = CURRENT_DATE"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Average order value this month ($)", "width": 1, "chart": {"type": "kpi"},
        "sql": "SELECT ROUND(AVG(TotalAmount), 2) AS AvgOrderValue FROM Sales.SalesOrder WHERE Status <> 'Cancelled' AND YEAR(OrderDate) = YEAR(CURRENT_DATE) AND MONTH(OrderDate) = MONTH(CURRENT_DATE)"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Products below minimum stock", "width": 1, "chart": {"type": "kpi"},
        "sql": "SELECT COUNT(*) AS Items FROM Inventory.StockLevel WHERE Quantity < MinimumQty"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Monthly revenue by channel", "width": 2, "chart": {"type": "line", "x": "Month", "y": ["Revenue"], "series": "Channel"},
        "sql": "SELECT TO_CHAR(CAST(OrderDate AS DATE), 'YYYY-MM') AS Month, %EXACT(Channel) AS Channel, ROUND(SUM(TotalAmount), 2) AS Revenue FROM Sales.SalesOrder WHERE Status <> 'Cancelled' AND OrderDate >= DATEADD('mm', -12, CURRENT_DATE) GROUP BY TO_CHAR(CAST(OrderDate AS DATE), 'YYYY-MM'), %EXACT(Channel) ORDER BY Month"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Revenue by region (12 months)", "width": 2, "chart": {"type": "doughnut", "x": "Region", "y": ["Revenue"]},
        "sql": "SELECT %EXACT(b.Region) AS Region, ROUND(SUM(o.TotalAmount), 2) AS Revenue FROM Sales.SalesOrder o JOIN Core.Branch b ON b.BranchID = o.BranchID WHERE o.Status <> 'Cancelled' AND o.OrderDate >= DATEADD('mm', -12, CURRENT_DATE) GROUP BY %EXACT(b.Region) ORDER BY Revenue DESC"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Top 10 categories by gross margin ($)", "width": 2, "chart": {"type": "hbar", "x": "Category", "y": ["Margin"]},
        "sql": "SELECT TOP 10 %EXACT(c.Name) AS Category, ROUND(SUM(i.LineTotal - (i.Quantity * p.UnitCost)), 2) AS Margin FROM Sales.OrderItem i JOIN Core.Product p ON p.ProductID = i.ProductID JOIN Core.Category c ON c.CategoryID = p.CategoryID JOIN Sales.SalesOrder o ON o.OrderID = i.OrderID WHERE o.Status <> 'Cancelled' GROUP BY %EXACT(c.Name) ORDER BY Margin DESC"})
    Do ##class(Copilot.API.Facade).SaveWidget({"dashboardId": (id), "title": "Latest orders", "width": 2, "chart": {"type": "table"},
        "sql": "SELECT TOP 10 o.OrderID, o.OrderDate, c.Name AS Customer, b.Name AS Branch, o.Channel, o.Status, o.TotalAmount FROM Sales.SalesOrder o JOIN Core.Customer c ON c.CustomerID = o.CustomerID JOIN Core.Branch b ON b.BranchID = o.BranchID ORDER BY o.OrderID DESC"})
}

}
