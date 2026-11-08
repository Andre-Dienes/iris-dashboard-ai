/// Real-time sales simulator (demo dataset only): inserts a new order every N seconds and moves
/// recent orders through their statuses, so auto-refreshing dashboards show live data.
///
///   Do ##class(Copilot.Setup.Simulator).Start(5)   /   Do ##class(Copilot.Setup.Simulator).Stop()
/// Controlled by SIMULATOR_INTERVAL (seconds; 0 disables it).
Class Copilot.Setup.Simulator Extends %RegisteredObject
{

ClassMethod Start(interval As %Integer = "") As %Status
{
    Set:interval="" interval = +##class(Copilot.Core.Config).Get("SIMULATOR_INTERVAL", 5)
    Quit:interval<=0 $$$OK
    Quit:'##class(Copilot.Setup.DemoData).Exists() $$$OK
    Do ..Stop()
    Set ^Copilot.Simulator("interval") = interval
    Set ^Copilot.Simulator("running") = 1
    Job ..Loop()
    Quit $$$OK
}

ClassMethod Stop() As %Status
{
    Set ^Copilot.Simulator("running") = 0
    Set pid = $Get(^Copilot.Simulator("pid"))
    Hang:pid'="" 0.5
    Quit $$$OK
}

ClassMethod Loop()
{
    Set ^Copilot.Simulator("pid") = $Job
    While $Get(^Copilot.Simulator("running")) {
        Try {
            Do ..Tick()
        } Catch ex {
            Set ^Copilot.Simulator("lastError") = ex.DisplayString()
        }
        Hang +$Get(^Copilot.Simulator("interval"), 5)
    }
    Kill ^Copilot.Simulator("pid")
}

/// One new order "now" + status progression of recent orders.
ClassMethod Tick()
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(OrderID) AS O FROM Sales.SalesOrder")
    Do rs.%Next()
    Set orderId = rs.%Get("O") + 1
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ItemID) AS I FROM Sales.OrderItem")
    Do rs.%Next()
    Set itemId = +rs.%Get("I")
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(PaymentID) AS P FROM Finance.Payment")
    Do rs.%Next()
    Set payId = +rs.%Get("P")

    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 CustomerID, Segment FROM Core.Customer WHERE CustomerID >= ? ORDER BY CustomerID", 1 + $Random(3000))
    Quit:'rs.%Next()
    Set cust = rs.%Get("CustomerID"), seg = rs.%Get("Segment")
    Set r = $Random(100), channel = $Select(r<50:"Store", r<80:"E-commerce", r<88:"Phone", 1:"Marketplace")
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 SalespersonID, BranchID FROM Core.Salesperson WHERE SalespersonID >= ? AND Active = 1 ORDER BY SalespersonID", 1 + $Random(90))
    If 'rs.%Next() {
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 SalespersonID, BranchID FROM Core.Salesperson ORDER BY SalespersonID")
        Do rs.%Next()
    }
    Set sp = rs.%Get("SalespersonID"), branch = rs.%Get("BranchID")
    Set:(channel="E-commerce")||(channel="Marketplace") sp = ""
    Set ts = $ZDateTime($Horolog, 3)

    Set gross = 0, n = 1 + $Random($Select(seg="Consumer":3, 1:5))
    For i=1:1:n {
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ProductID, UnitPrice FROM Core.Product WHERE ProductID >= ? AND Active = 1 ORDER BY ProductID", 1 + $Random(130))
        Continue:'rs.%Next()
        Set qty = $Select(seg="Consumer":1, 1:1 + $Random(8)), price = rs.%Get("UnitPrice"), line = $Normalize(price * qty, 2)
        Set itemId = itemId + 1, gross = gross + line
        Set item(i) = $ListBuild(itemId, rs.%Get("ProductID"), qty, price, line)
    }
    Quit:gross=0
    Set discount = $Select($Random(4)=0:$Normalize(gross * 0.05, 2), 1:0)
    &sql(INSERT INTO Sales.SalesOrder (OrderID, CustomerID, SalespersonID, BranchID, OrderDate, Channel, Status, GrossAmount, Discount, TotalAmount)
         VALUES (:orderId, :cust, :sp, :branch, :ts, :channel, 'Paid', :gross, :discount, :gross - :discount))
    Quit:SQLCODE<0
    Set i = ""
    For {
        Set i = $Order(item(i), 1, it)
        Quit:i=""
        Set id = $List(it, 1), prod = $List(it, 2), qty = $List(it, 3), price = $List(it, 4), line = $List(it, 5)
        &sql(INSERT INTO Sales.OrderItem (ItemID, OrderID, ProductID, Quantity, UnitPrice, LineTotal) VALUES (:id, :orderId, :prod, :qty, :price, :line))
    }
    Set r = $Random(100), method = $Select(r<50:"Credit Card", r<75:"Debit Card", 1:"Digital Wallet")
    Set payId = payId + 1, amount = gross - discount
    &sql(INSERT INTO Finance.Payment (PaymentID, OrderID, Method, Installments, Amount, PaidAt, Status) VALUES (:payId, :orderId, :method, 1, :amount, :ts, 'Approved'))
    // stock decrease
    Set i = ""
    For {
        Set i = $Order(item(i), 1, it)
        Quit:i=""
        Set prod = $List(it, 2), qty = $List(it, 3)
        &sql(UPDATE Inventory.StockLevel SET Quantity = CASE WHEN Quantity > :qty THEN Quantity - :qty ELSE 40 END, UpdatedAt = :ts WHERE ProductID = :prod AND BranchID = :branch)
    }
    // move recent orders forward
    &sql(UPDATE Sales.SalesOrder SET Status = 'Shipped' WHERE Status = 'Paid' AND OrderDate < DATEADD('mi', -2, NOW()) AND OrderID > :orderId - 200)
    &sql(UPDATE Sales.SalesOrder SET Status = 'Delivered' WHERE Status = 'Shipped' AND OrderDate < DATEADD('mi', -5, NOW()) AND OrderID > :orderId - 300)
    Set ^Copilot.Simulator("lastTick") = ts, ^Copilot.Simulator("orders") = $Get(^Copilot.Simulator("orders")) + 1
}

}
