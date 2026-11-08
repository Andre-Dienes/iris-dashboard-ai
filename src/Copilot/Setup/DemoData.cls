/// Demo dataset: a fictional US retail chain in 4 related schemas
/// (Core, Sales, Finance, Inventory), created through DDL with foreign keys and descriptions
/// (%DESCRIPTION) - which the Copilot passes to the LLM as context to build correct JOINs.
///
///   Do ##class(Copilot.Setup.DemoData).Load()        (idempotent)
///   Do ##class(Copilot.Setup.DemoData).Load(1)       (rebuilds everything)
///   Do ##class(Copilot.Setup.DemoData).DropAll()     (removes the demo tables)
Class Copilot.Setup.DemoData Extends %RegisteredObject
{

ClassMethod Load(force As %Boolean = 0, orders As %Integer = 15000) As %Status
{
    Set sc = $$$OK
    Try {
        If 'force, ..Exists() {
            Write "Demo dataset already exists.",!
            Quit
        }
        Do ..DropAll()
        Do ..CreateTables()
        Do ..Populate(orders)
        Do ##class(Copilot.Core.Schema).Refresh()
        Write "Demo dataset created.",!
    } Catch ex {
        Set sc = ex.AsStatus()
        Write "Load error: ",ex.DisplayString(),!
    }
    Quit sc
}

ClassMethod Exists() As %Boolean
{
    Quit ##class(%Dictionary.CompiledClass).%ExistsId("Sales.SalesOrder")
}

ClassMethod Exec(sql As %String)
{
    Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    If rs.%SQLCODE<0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "SQLCODE "_rs.%SQLCODE_" "_rs.%Message_" in: "_$Extract(sql, 1, 120)))
    }
}

ClassMethod DropAll()
{
    For t="Inventory.StockLevel","Finance.Payment","Sales.OrderItem","Sales.SalesOrder","Core.Product","Core.Category","Core.Customer","Core.Salesperson","Core.Branch" {
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "DROP TABLE "_t_" %DELDATA")
    }
    Do ##class(Copilot.Core.Schema).Refresh()
}

ClassMethod CreateTables()
{
    Do ..Exec("CREATE TABLE Core.Branch ("_
        "BranchID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Branch (store) code', "_
        "Name VARCHAR(80) NOT NULL %DESCRIPTION 'Branch name', "_
        "City VARCHAR(60) %DESCRIPTION 'Branch city', "_
        "State CHAR(2) %DESCRIPTION 'US state (two-letter code)', "_
        "Region VARCHAR(20) %DESCRIPTION 'US region: Northeast, Midwest, South or West', "_
        "OpenDate DATE %DESCRIPTION 'Opening date', "_
        "AreaSqFt INTEGER %DESCRIPTION 'Sales floor area in square feet', "_
        "%DESCRIPTION 'Branches (physical stores) of the chain')")
    Do ..Exec("CREATE TABLE Core.Salesperson ("_
        "SalespersonID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Salesperson code', "_
        "Name VARCHAR(80) NOT NULL %DESCRIPTION 'Salesperson name', "_
        "BranchID INTEGER NOT NULL %DESCRIPTION 'Branch where the salesperson works', "_
        "HireDate DATE %DESCRIPTION 'Hire date', "_
        "MonthlyTarget NUMERIC(12,2) %DESCRIPTION 'Monthly sales target in USD', "_
        "Active BIT %DESCRIPTION '1 = active, 0 = terminated', "_
        "CONSTRAINT FK_Salesperson_Branch FOREIGN KEY (BranchID) REFERENCES Core.Branch (BranchID), "_
        "%DESCRIPTION 'Salespeople of the chain')")
    Do ..Exec("CREATE TABLE Core.Customer ("_
        "CustomerID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Customer code', "_
        "Name VARCHAR(100) NOT NULL %DESCRIPTION 'Customer or company name', "_
        "Email VARCHAR(120) %DESCRIPTION 'E-mail', "_
        "City VARCHAR(60) %DESCRIPTION 'Customer city', "_
        "State CHAR(2) %DESCRIPTION 'Customer US state (two-letter code)', "_
        "Segment VARCHAR(20) %DESCRIPTION 'Segment: Consumer, Wholesale or Corporate', "_
        "SignupDate DATE %DESCRIPTION 'Customer registration date', "_
        "BirthDate DATE %DESCRIPTION 'Birth date (consumers only)', "_
        "%DESCRIPTION 'Customers of the chain')")
    Do ..Exec("CREATE TABLE Core.Category ("_
        "CategoryID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Category code', "_
        "Name VARCHAR(60) NOT NULL %DESCRIPTION 'Category name', "_
        "Department VARCHAR(40) %DESCRIPTION 'Department that groups categories', "_
        "%DESCRIPTION 'Product categories')")
    Do ..Exec("CREATE TABLE Core.Product ("_
        "ProductID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Product code (SKU)', "_
        "Name VARCHAR(100) NOT NULL %DESCRIPTION 'Product description', "_
        "CategoryID INTEGER NOT NULL %DESCRIPTION 'Product category', "_
        "Brand VARCHAR(40) %DESCRIPTION 'Brand', "_
        "UnitPrice NUMERIC(12,2) %DESCRIPTION 'Current list price in USD', "_
        "UnitCost NUMERIC(12,2) %DESCRIPTION 'Unit cost in USD. Gross margin of an item = OrderItem.LineTotal - OrderItem.Quantity * Product.UnitCost', "_
        "Active BIT %DESCRIPTION '1 = active, 0 = discontinued', "_
        "CONSTRAINT FK_Product_Category FOREIGN KEY (CategoryID) REFERENCES Core.Category (CategoryID), "_
        "%DESCRIPTION 'Product catalog')")
    Do ..Exec("CREATE TABLE Sales.SalesOrder ("_
        "OrderID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Order number', "_
        "CustomerID INTEGER NOT NULL %DESCRIPTION 'Customer who bought', "_
        "SalespersonID INTEGER %DESCRIPTION 'Salesperson in charge (null for online sales)', "_
        "BranchID INTEGER NOT NULL %DESCRIPTION 'Branch that invoiced the order', "_
        "OrderDate TIMESTAMP NOT NULL %DESCRIPTION 'Order date and time', "_
        "Channel VARCHAR(20) %DESCRIPTION 'Sales channel: Store, E-commerce, Phone or Marketplace', "_
        "Status VARCHAR(20) %DESCRIPTION 'Status: Open, Paid, Shipped, Delivered or Cancelled', "_
        "GrossAmount NUMERIC(14,2) %DESCRIPTION 'Sum of the items in USD before discount', "_
        "Discount NUMERIC(14,2) %DESCRIPTION 'Discount granted in USD (not margin)', "_
        "TotalAmount NUMERIC(14,2) %DESCRIPTION 'Net order value in USD (revenue)', "_
        "CONSTRAINT FK_Order_Customer FOREIGN KEY (CustomerID) REFERENCES Core.Customer (CustomerID), "_
        "CONSTRAINT FK_Order_Salesperson FOREIGN KEY (SalespersonID) REFERENCES Core.Salesperson (SalespersonID), "_
        "CONSTRAINT FK_Order_Branch FOREIGN KEY (BranchID) REFERENCES Core.Branch (BranchID), "_
        "%DESCRIPTION 'Sales orders (header). Revenue = SUM(TotalAmount) of non-cancelled orders')")
    Do ..Exec("CREATE TABLE Sales.OrderItem ("_
        "ItemID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Item code', "_
        "OrderID INTEGER NOT NULL %DESCRIPTION 'Order the item belongs to', "_
        "ProductID INTEGER NOT NULL %DESCRIPTION 'Product sold', "_
        "Quantity INTEGER %DESCRIPTION 'Quantity sold', "_
        "UnitPrice NUMERIC(12,2) %DESCRIPTION 'Unit price charged in USD', "_
        "LineTotal NUMERIC(14,2) %DESCRIPTION 'Quantity x unit price in USD (gross, before the order discount; for revenue use Sales.SalesOrder.TotalAmount)', "_
        "CONSTRAINT FK_Item_Order FOREIGN KEY (OrderID) REFERENCES Sales.SalesOrder (OrderID), "_
        "CONSTRAINT FK_Item_Product FOREIGN KEY (ProductID) REFERENCES Core.Product (ProductID), "_
        "%DESCRIPTION 'Sales order items')")
    Do ..Exec("CREATE TABLE Finance.Payment ("_
        "PaymentID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Payment code', "_
        "OrderID INTEGER NOT NULL %DESCRIPTION 'Order paid', "_
        "Method VARCHAR(30) %DESCRIPTION 'Payment method: Credit Card, Debit Card, Digital Wallet or Bank Transfer', "_
        "Installments INTEGER %DESCRIPTION 'Number of installments', "_
        "Amount NUMERIC(14,2) %DESCRIPTION 'Amount paid in USD', "_
        "PaidAt TIMESTAMP %DESCRIPTION 'Payment date and time', "_
        "Status VARCHAR(20) %DESCRIPTION 'Approved, Declined or Refunded', "_
        "CONSTRAINT FK_Payment_Order FOREIGN KEY (OrderID) REFERENCES Sales.SalesOrder (OrderID), "_
        "%DESCRIPTION 'Order payments')")
    Do ..Exec("CREATE TABLE Inventory.StockLevel ("_
        "StockID INTEGER NOT NULL PRIMARY KEY %DESCRIPTION 'Stock record code', "_
        "ProductID INTEGER NOT NULL %DESCRIPTION 'Product', "_
        "BranchID INTEGER NOT NULL %DESCRIPTION 'Branch', "_
        "Quantity INTEGER %DESCRIPTION 'Quantity on hand', "_
        "MinimumQty INTEGER %DESCRIPTION 'Reorder point', "_
        "UpdatedAt TIMESTAMP %DESCRIPTION 'Last update', "_
        "CONSTRAINT FK_Stock_Product FOREIGN KEY (ProductID) REFERENCES Core.Product (ProductID), "_
        "CONSTRAINT FK_Stock_Branch FOREIGN KEY (BranchID) REFERENCES Core.Branch (BranchID), "_
        "%DESCRIPTION 'Stock on hand by product and branch')")
    Do ..Exec("CREATE INDEX IdxOrderDate ON Sales.SalesOrder (OrderDate)")
    Do ..Exec("CREATE INDEX IdxItemOrder ON Sales.OrderItem (OrderID)")
    Do ..Exec("CREATE INDEX IdxItemProduct ON Sales.OrderItem (ProductID)")
    Do ..Exec("CREATE INDEX IdxPaymentOrder ON Finance.Payment (OrderID)")
}

ClassMethod Populate(orders As %Integer)
{
    Set today = +$Horolog
    // ---------------- branches
    Set branches = $ListBuild(
        $ListBuild("New York Manhattan","New York","NY","Northeast"), $ListBuild("New York Brooklyn","New York","NY","Northeast"),
        $ListBuild("Boston Back Bay","Boston","MA","Northeast"), $ListBuild("Philadelphia Center City","Philadelphia","PA","Northeast"),
        $ListBuild("Chicago Loop","Chicago","IL","Midwest"), $ListBuild("Detroit Midtown","Detroit","MI","Midwest"),
        $ListBuild("Minneapolis Uptown","Minneapolis","MN","Midwest"), $ListBuild("Columbus Short North","Columbus","OH","Midwest"),
        $ListBuild("Atlanta Midtown","Atlanta","GA","South"), $ListBuild("Miami Brickell","Miami","FL","South"),
        $ListBuild("Dallas Uptown","Dallas","TX","South"), $ListBuild("Houston Galleria","Houston","TX","South"),
        $ListBuild("Charlotte South End","Charlotte","NC","South"), $ListBuild("Los Angeles Downtown","Los Angeles","CA","West"),
        $ListBuild("San Francisco SoMa","San Francisco","CA","West"), $ListBuild("Seattle Capitol Hill","Seattle","WA","West"),
        $ListBuild("Denver LoDo","Denver","CO","West"))
    Set ins = ..Prepare("INSERT INTO Core.Branch (BranchID, Name, City, State, Region, OpenDate, AreaSqFt) VALUES (?,?,?,?,?,?,?)")
    For i=1:1:$ListLength(branches) {
        Set b = $List(branches, i)
        // sales weight: large metro areas sell more
        Set weight(i) = $Case($List(b, 4), "Northeast":9, "South":9, "West":8, "Midwest":6, :4) + $Random(5)
        Do ..Insert(ins, i, $List(b, 1), $List(b, 2), $List(b, 3), $List(b, 4), today - 400 - $Random(3000), 4000 + ($Random(16) * 500))
    }
    Set nBranches = $ListLength(branches)
    Set totalWeight = 0
    For i=1:1:nBranches Set totalWeight = totalWeight + weight(i)

    // ---------------- names
    Set firstNames = $ListFromString("James,Mary,John,Patricia,Robert,Jennifer,Michael,Linda,William,Elizabeth,David,Barbara,Richard,Susan,Joseph,Jessica,Thomas,Sarah,Charles,Karen,Daniel,Nancy,Matthew,Lisa,Anthony,Emily,Mark,Ashley,Steven,Olivia,Andrew,Sophia,Joshua,Emma,Kevin,Ava,Brian,Mia,Ryan,Grace,Jacob,Chloe,Ethan,Zoe,Noah,Lily,Lucas,Ella")
    Set lastNames = $ListFromString("Smith,Johnson,Williams,Brown,Jones,Garcia,Miller,Davis,Rodriguez,Martinez,Hernandez,Lopez,Gonzalez,Wilson,Anderson,Thomas,Taylor,Moore,Jackson,Martin,Lee,Perez,Thompson,White,Harris,Clark,Lewis,Robinson,Walker,Young")
    Set companies = $ListFromString("Summit,Pioneer,Liberty,Evergreen,Keystone,Harbor,Frontier,Redwood,Lakeside,Granite,Beacon,Cardinal")
    Set companyTypes = $ListFromString("Supply,Distributors,Markets,Foods,Builders,Partners,Clinic,Hospitality,Logistics,Academy")

    // ---------------- salespeople (4 to 6 per branch)
    Set ins = ..Prepare("INSERT INTO Core.Salesperson (SalespersonID, Name, BranchID, HireDate, MonthlyTarget, Active) VALUES (?,?,?,?,?,?)")
    Set sid = 0
    For b=1:1:nBranches {
        For k=1:1:(4 + $Random(3)) {
            Set sid = sid + 1
            Set seller(b, k) = sid, seller(b) = k
            Do ..Insert(ins, sid, ..Pick(firstNames)_" "_..Pick(lastNames), b, today - 60 - $Random(2500), 15000 + ($Random(13) * 2500), $Select($Random(12)=0:0, 1:1))
        }
    }

    // ---------------- customers
    Set nCustomers = 3000
    Set ins = ..Prepare("INSERT INTO Core.Customer (CustomerID, Name, Email, City, State, Segment, SignupDate, BirthDate) VALUES (?,?,?,?,?,?,?,?)")
    For c=1:1:nCustomers {
        Set b = ..PickBranch(.weight, totalWeight, nBranches), bl = $List(branches, b)
        Set customerBranch(c) = b
        Set r = $Random(100), seg = $Select(r<75:"Consumer", r<92:"Wholesale", 1:"Corporate")
        Set segment(c) = seg
        If seg="Consumer" {
            Set name = ..Pick(firstNames)_" "_..Pick(lastNames), birth = today - (18 * 365) - $Random(50 * 365)
        } Else {
            Set name = ..Pick(companies)_" "_..Pick(companyTypes)_$Select($Random(2):" LLC", 1:" Inc."), birth = ""
        }
        Set email = $ZConvert($Piece(name, " ", 1)_"."_$Piece(name, " ", 2), "L")_c_"@example.com"
        Do ..Insert(ins, c, name, email, $List(bl, 2), $List(bl, 3), seg, today - 30 - $Random(1500), birth)
    }

    // ---------------- categories and products (prices in USD)
    Set cats = $ListBuild(
        $ListBuild("Smartphones","Electronics",199,1199,$ListFromString("Galaxy A55,Galaxy S24,iPhone 15,iPhone 15 Pro,Moto G Power,Pixel 8,Pixel 8 Pro")),
        $ListBuild("Laptops","Computers",399,2499,$ListFromString("IdeaPad 3,Inspiron 15,Vivobook 16,MacBook Air M3,Aspire 5,ThinkPad E14")),
        $ListBuild("Accessories","Computers",15,349,$ListFromString("Wireless Mouse,Mechanical Keyboard,Gaming Headset,HD Webcam,24-inch Monitor,USB-C Hub,1TB SSD")),
        $ListBuild("TVs","Electronics",249,2499,$ListFromString("43-inch Smart TV,50-inch Smart TV,55-inch QLED TV,65-inch OLED TV,Soundbar")),
        $ListBuild("Appliances","Home",49,1999,$ListFromString("French Door Refrigerator,Front Load Washer,Microwave Oven,Air Fryer,Robot Vacuum,Gas Range,Coffee Maker")),
        $ListBuild("Furniture","Home",79,1499,$ListFromString("3-Seat Sofa,Dining Table,Office Chair,Wardrobe,TV Stand,Queen Bed Frame")),
        $ListBuild("Sports","Outdoors",15,899,$ListFromString("Mountain Bike,Treadmill,Dumbbell Set,Running Shoes,Soccer Ball,Camping Tent")),
        $ListBuild("Beauty","Health & Beauty",9,199,$ListFromString("Hair Dryer,Flat Iron,Eau de Parfum,Skincare Kit,Electric Shaver")),
        $ListBuild("Toys","Outdoors",10,249,$ListFromString("Building Blocks,Fashion Doll,RC Car,Board Game,Plush Toy")),
        $ListBuild("Gaming","Electronics",39,599,$ListFromString("PlayStation 5,Xbox Series X,Wireless Controller,New Release Game,Gaming Chair")),
        $ListBuild("Tools","Home",19,499,$ListFromString("Cordless Drill,Impact Driver,Socket Set,Jigsaw,Pressure Washer")),
        $ListBuild("Books","Outdoors",8,59,$ListFromString("Novel,Biography,Self-Help,Children's Book,Programming Guide")))
    Set brands = $ListFromString("Aurora,Breeze,Cosmos,Delta,Echo,Fortis,Gamma,Horizon,Icon,Jade")
    Set insC = ..Prepare("INSERT INTO Core.Category (CategoryID, Name, Department) VALUES (?,?,?)")
    Set insP = ..Prepare("INSERT INTO Core.Product (ProductID, Name, CategoryID, Brand, UnitPrice, UnitCost, Active) VALUES (?,?,?,?,?,?,?)")
    Set pid = 0
    For c=1:1:$ListLength(cats) {
        Set cat = $List(cats, c)
        Do ..Insert(insC, c, $List(cat, 1), $List(cat, 2))
        Set models = $List(cat, 5), pmin = $List(cat, 3), pmax = $List(cat, 4)
        For m=1:1:$ListLength(models) {
            For v=1:1:(1 + $Random(2)) {
                Set pid = pid + 1
                Set price = pmin + $Random(pmax - pmin + 1), price = (price \ 5 * 5) - 0.01
                Set costRatio = 0.55 + ($Random(30) / 100)
                Set prod(pid) = $ListBuild(price, c)
                Set productName = $List(models, m)_$Select(v=2:" Plus", 1:"")
                Do ..Insert(insP, pid, productName, c, ..Pick(brands), price, $Normalize(price * costRatio, 2), $Select($Random(15)=0:0, 1:1))
                // popularity: cheaper products sell more
                Set popular(pid) = $Select(price<60:6, price<300:4, price<800:2, 1:1)
            }
        }
    }
    Set nProd = pid
    Set totalPop = 0
    For p=1:1:nProd Set totalPop = totalPop + popular(p), popAcc(p) = totalPop

    // ---------------- orders, items and payments (last ~24 months, seasonality and growth)
    Set insOrd = ..Prepare("INSERT INTO Sales.SalesOrder (OrderID, CustomerID, SalespersonID, BranchID, OrderDate, Channel, Status, GrossAmount, Discount, TotalAmount) VALUES (?,?,?,?,?,?,?,?,?,?)")
    Set insItem = ..Prepare("INSERT INTO Sales.OrderItem (ItemID, OrderID, ProductID, Quantity, UnitPrice, LineTotal) VALUES (?,?,?,?,?,?)")
    Set insPay = ..Prepare("INSERT INTO Finance.Payment (PaymentID, OrderID, Method, Installments, Amount, PaidAt, Status) VALUES (?,?,?,?,?,?,?)")
    Set days = 730, itemId = 0, payId = 0
    // cumulative distribution of days with growth and seasonality (Black Friday / holidays peak)
    Set acc = 0
    For d=1:1:days {
        Set dt = today - days + d
        Set month = +$Piece($ZDate(dt, 3), "-", 2), dow = $ZDate(dt, 10)
        Set w = (1 + (d / days * 0.6)) * $Case(month, 11:1.6, 12:1.9, 1:0.8, 2:0.85, 5:1.1, 7:1.1, :1) * $Case(dow, 0:0.8, 6:1.3, 5:1.15, :1)
        Set acc = acc + w, dayAcc(d) = acc
    }
    Set totalW = acc
    For o=1:1:orders {
        Set d = ..PickAcc(.dayAcc, days, totalW)
        Set dt = today - days + d
        Set hour = $Select($Random(10)<7:10 + $Random(10), 1:$Random(24))
        Set ts = $ZDate(dt, 3)_" "_$Translate($Justify(hour, 2), " ", "0")_":"_$Translate($Justify($Random(60), 2), " ", "0")_":"_$Translate($Justify($Random(60), 2), " ", "0")
        Set cust = 1 + $Random(nCustomers)
        Set r = $Random(100), channel = $Select(r<50:"Store", r<80:"E-commerce", r<88:"Phone", 1:"Marketplace")
        Set branch = $Select(channel="Store":customerBranch(cust), 1:..PickBranch(.weight, totalWeight, nBranches))
        Set sp = $Select((channel="Store")||(channel="Phone"):seller(branch, 1 + $Random(seller(branch))), 1:"")
        Set age = today - dt
        Set r = $Random(100)
        Set status = $Select(r<6:"Cancelled", age<2:$Select(r<50:"Open", 1:"Paid"), age<6:$Select(r<40:"Paid", 1:"Shipped"), 1:"Delivered")
        // items
        Set nItems = $Select(segment(cust)="Consumer":1 + $Random(3), 1:2 + $Random(5))
        Set gross = 0
        Kill used, items
        For it=1:1:nItems {
            Set p = ..PickAcc(.popAcc, nProd, totalPop)
            Continue:$Data(used(p))
            Set used(p) = 1
            Set qty = $Select(segment(cust)="Consumer":1 + ($Random(5)=0), segment(cust)="Wholesale":2 + $Random(10), 1:1 + $Random(6))
            Set price = $List(prod(p), 1)
            // price actually charged varies (promotions)
            Set price = $Normalize(price * (0.9 + ($Random(11) / 100)), 2)
            Set line = $Normalize(price * qty, 2)
            Set itemId = itemId + 1, gross = gross + line
            Set items(itemId) = $ListBuild(p, qty, price, line)
        }
        Set discount = $Select($Random(4)=0:$Normalize(gross * ($Random(12) / 100), 2), 1:0)
        Set net = gross - discount
        Do ..Insert(insOrd, o, cust, sp, branch, ts, channel, status, gross, discount, net)
        Set it = ""
        For {
            Set it = $Order(items(it), 1, item)
            Quit:it=""
            Do ..Insert(insItem, it, o, $List(item, 1), $List(item, 2), $List(item, 3), $List(item, 4))
        }
        // payment
        If status'="Open" {
            Set r = $Random(100), method = $Select(r<45:"Credit Card", r<70:"Debit Card", r<90:"Digital Wallet", 1:"Bank Transfer")
            Set installments = $Select(method="Credit Card":$Select(net>500:1 + $Random(6), 1:1), 1:1)
            Set pstatus = $Select(status="Cancelled":$Select($Random(2):"Refunded", 1:"Declined"), 1:"Approved")
            Set payId = payId + 1
            Do ..Insert(insPay, payId, o, method, installments, net, ts, pstatus)
        }
        Write:o#5000=0 "  ",o," orders",!
    }

    // ---------------- inventory
    Set ins = ..Prepare("INSERT INTO Inventory.StockLevel (StockID, ProductID, BranchID, Quantity, MinimumQty, UpdatedAt) VALUES (?,?,?,?,?,?)")
    Set stockId = 0, now = $ZDateTime($Horolog, 3)
    For b=1:1:nBranches {
        For p=1:1:nProd {
            Set stockId = stockId + 1, minimum = 3 + $Random(8)
            Do ..Insert(ins, stockId, p, b, $Select($Random(9)=0:$Random(minimum), 1:minimum + $Random(60)), minimum, now)
        }
    }
    Write "Branches: ",nBranches,"  Salespeople: ",sid,"  Customers: ",nCustomers,"  Products: ",nProd,"  Orders: ",orders,"  Items: ",itemId,!
    Do ..Exec("TUNE TABLE Sales.SalesOrder")
    Do ..Exec("TUNE TABLE Sales.OrderItem")
}

ClassMethod Prepare(sql As %String) As %SQL.Statement
{
    Set stmt = ##class(%SQL.Statement).%New()
    $$$ThrowOnError(stmt.%Prepare(sql))
    Quit stmt
}

ClassMethod Insert(stmt As %SQL.Statement, args...)
{
    Set rs = stmt.%Execute(args...)
    If rs.%SQLCODE<0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "SQLCODE "_rs.%SQLCODE_" "_rs.%Message))
    }
}

ClassMethod Pick(list As %List) As %String
{
    Quit $List(list, 1 + $Random($ListLength(list)))
}

ClassMethod PickBranch(ByRef weight, total As %Integer, n As %Integer) As %Integer
{
    Set r = $Random(total), acc = 0
    For i=1:1:n {
        Set acc = acc + weight(i)
        Return:r<acc i
    }
    Quit n
}

/// Binary search on a cumulative distribution acc(1..n).
ClassMethod PickAcc(ByRef acc, n As %Integer, total As %Numeric) As %Integer
{
    Set r = $Random(1000000) / 1000000 * total
    Set lo = 1, hi = n
    While lo < hi {
        Set mid = (lo + hi) \ 2
        If acc(mid) < r {
            Set lo = mid + 1
        } Else {
            Set hi = mid
        }
    }
    Quit lo
}

}
