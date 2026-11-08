Include Ensemble

/// Interoperability helpers for the portal: production lifecycle, component status and message trace
/// (the portal shows its own trace viewer, so it also works on images without the Management Portal).
Class Copilot.Interop.Util Extends %RegisteredObject
{

Parameter PRODUCTION = "Copilot.Interop.Production";

ClassMethod IsRunning() As %Boolean
{
    Set sc = ##class(Ens.Director).GetProductionStatus(.name, .state)
    Quit $$$ISOK(sc) && (state=1) && (name=..#PRODUCTION)
}

/// Starts the production (idempotent).
ClassMethod Start() As %Status
{
    Quit:..IsRunning() $$$OK
    Set sc = ##class(Ens.Director).StartProduction(..#PRODUCTION)
    Quit:$System.Status.Equals(sc, $$$EnsErrProductionAlreadyRunning) $$$OK
    Quit sc
}

/// {"production","running","items":[{name,className,category,comment,enabled,queue,lastActivity,messagesLastHour,errorsLastHour}]}
ClassMethod Status() As %DynamicObject
{
    Set out = {"production": (..#PRODUCTION), "running": (..IsRunning()), "items": []}
    Set prod = ##class(Ens.Config.Production).%OpenId(..#PRODUCTION)
    Quit:'$IsObject(prod) out
    // Ens.MessageHeader times are UTC: one hour ago in UTC
    Set now = $ZTimeStamp, secs = ($Piece(now, ",") * 86400) + $Piece(now, ",", 2) - 3600
    Set since = $ZDateTime((secs \ 86400)_","_(secs # 86400), 3)
    For i=1:1:prod.Items.Count() {
        Set item = prod.Items.GetAt(i), name = item.Name
        Set kind = $Select(item.BusinessType()=1:"service", item.BusinessType()=2:"process", item.BusinessType()=3:"operation", 1:"")
        Set queue = 0
        Try {
            Set queue = ##class(Ens.Queue).GetCount(name)
        } Catch {
        }
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(TimeCreated) AS L, SUM(CASE WHEN TimeCreated >= ? THEN 1 ELSE 0 END) AS N, SUM(CASE WHEN TimeCreated >= ? AND IsError = 1 THEN 1 ELSE 0 END) AS E FROM Ens.MessageHeader WHERE TargetConfigName = ? OR SourceConfigName = ?", since, since, name, name)
        Do rs.%Next()
        Do out.items.%Push({"name": (name), "className": (item.ClassName), "kind": (kind), "category": (item.Category), "comment": (item.Comment),
            "enabled": (+item.Enabled), "poolSize": (+item.PoolSize), "queue": (+queue), "lastActivity": (rs.%Get("L")),
            "messagesLastHour": (+rs.%Get("N")), "errorsLastHour": (+rs.%Get("E"))})
    }
    Quit out
}

/// Latest sessions: [{sessionId, started, source, firstTarget, messages, errors, kind}]
ClassMethod Sessions(limit As %Integer = 40) As %DynamicArray
{
    Set out = []
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP ? SessionId, MIN(TimeCreated) AS Started, COUNT(*) AS N, SUM(IsError) AS E FROM Ens.MessageHeader GROUP BY SessionId ORDER BY SessionId DESC", limit)
    While rs.%Next() {
        Set sid = rs.%Get("SessionId")
        Set first = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 SourceConfigName, TargetConfigName, MessageBodyClassName FROM Ens.MessageHeader WHERE SessionId = ? ORDER BY ID", sid)
        Do first.%Next()
        Set body = first.%Get("MessageBodyClassName")
        Do out.%Push({"sessionId": (sid), "started": (rs.%Get("Started")), "messages": (+rs.%Get("N")), "errors": (+rs.%Get("E")),
            "source": (first.%Get("SourceConfigName")), "target": (first.%Get("TargetConfigName")),
            "kind": ($Select(body["Ask":"ask", body["Report":"report", 1:"other"))})
    }
    Quit out
}

/// Every message of a session, in order, with a short preview of its body.
ClassMethod Trace(sessionId As %Integer) As %DynamicObject
{
    Set out = {"sessionId": (sessionId), "messages": []}
    Set stmt = ##class(%SQL.Statement).%New()
    Set stmt.%SelectMode = 2
    $$$ThrowOnError(stmt.%Prepare("SELECT ID, TimeCreated, TimeProcessed, SourceConfigName, TargetConfigName, MessageBodyClassName, MessageBodyId, Type, Status, IsError, ErrorStatus FROM Ens.MessageHeader WHERE SessionId = ? ORDER BY ID"))
    Set rs = stmt.%Execute(sessionId)
    While rs.%Next() {
        Set cls = rs.%Get("MessageBodyClassName"), bodyId = rs.%Get("MessageBodyId")
        Do out.messages.%Push({"id": (rs.%Get("ID")), "created": (rs.%Get("TimeCreated")), "processed": (rs.%Get("TimeProcessed")),
            "source": (rs.%Get("SourceConfigName")), "target": (rs.%Get("TargetConfigName")), "bodyClass": (cls),
            "type": (rs.%Get("Type")), "status": (rs.%Get("Status")), "isError": (+rs.%Get("IsError")),
            "error": ($Select(+rs.%Get("IsError"):$System.Status.GetErrorText(rs.%Get("ErrorStatus")), 1:"")),
            "body": (..BodyPreview(cls, bodyId))})
    }
    Quit out
}

/// Properties of a message body (each value truncated) for the trace viewer.
ClassMethod BodyPreview(cls As %String, id As %String) As %DynamicObject
{
    Set out = {}
    Quit:(cls="")||(id="") out
    Try {
        Set obj = $ClassMethod(cls, "%OpenId", id)
        Quit:'$IsObject(obj)
        Set def = ##class(%Dictionary.CompiledClass).%OpenId(cls)
        For i=1:1:def.Properties.Count() {
            Set prop = def.Properties.GetAt(i)
            Continue:$Extract(prop.Name)="%"
            Continue:prop.Private||prop.Calculated||prop.Transient
            Continue:prop.Origin'[cls&&(prop.Origin'["Copilot.")
            Set v = $Property(obj, prop.Name)
            Continue:$IsObject(v)
            Continue:v=""
            Set:$Length(v)>400 v = $Extract(v, 1, 400)_" ... ("_$Length(v)_" chars)"
            Do out.%Set(prop.Name, v)
        }
    } Catch {
    }
    Quit out
}

}
