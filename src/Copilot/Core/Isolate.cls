/// Runs a class method in another IRIS process (JOB) and waits for its (string) result.
///
/// Why: in the AI Hub EAP builds, an LLM call nested inside a tool of a running %AI.Agent, or made
/// from a long-lived server process, can break the AI-Core bridge. Every AI operation therefore runs
/// in a fresh process, at the top of its stack. The child process inherits namespace, user and roles.
Class Copilot.Core.Isolate Extends %RegisteredObject
{

ClassMethod Call(class As %String, method As %String, timeoutSecs As %Integer = 300, args...) As %String
{
    Set key = $System.Util.CreateGUID()
    Set ^IRIS.Temp.Copilot(key, "class") = class
    Set ^IRIS.Temp.Copilot(key, "method") = method
    Set ^IRIS.Temp.Copilot(key, "args") = +$Get(args)
    // the worker answers in the same language as the caller
    Set ^IRIS.Temp.Copilot(key, "lang") = $Get(%CopilotLang)
    For i=1:1:+$Get(args) {
        Do ..PutLong($Name(^IRIS.Temp.Copilot(key, "args", i)), $Get(args(i)))
    }
    Job ..Worker(key)::10
    If '$Test {
        Kill ^IRIS.Temp.Copilot(key)
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Isolate: could not start the worker job"))
    }
    Set deadline = $ZHorolog + timeoutSecs
    While '$Data(^IRIS.Temp.Copilot(key, "done")) {
        If $ZHorolog > deadline {
            Kill ^IRIS.Temp.Copilot(key)
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Timed out ("_timeoutSecs_"s) in "_class_":"_method))
        }
        Hang 0.1
    }
    Set error = $Get(^IRIS.Temp.Copilot(key, "error"))
    Set result = ..GetLong($Name(^IRIS.Temp.Copilot(key, "result")))
    Kill ^IRIS.Temp.Copilot(key)
    If error'="" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, error))
    }
    Quit result
}

ClassMethod Worker(key As %String)
{
    Try {
        Set class = ^IRIS.Temp.Copilot(key, "class"), method = ^IRIS.Temp.Copilot(key, "method")
        Do ##class(Copilot.Core.Config).SetLang($Get(^IRIS.Temp.Copilot(key, "lang")))
        Set n = +$Get(^IRIS.Temp.Copilot(key, "args"))
        For i=1:1:n {
            Set args(i) = ..GetLong($Name(^IRIS.Temp.Copilot(key, "args", i)))
        }
        Set args = n
        Set result = $ClassMethod(class, method, args...)
        Do ..PutLong($Name(^IRIS.Temp.Copilot(key, "result")), result)
    } Catch ex {
        Set ^IRIS.Temp.Copilot(key, "error") = ex.DisplayString()
    }
    Set ^IRIS.Temp.Copilot(key, "done") = 1
}

/// Stores a long string in 1 MB pieces under the given node.
ClassMethod PutLong(ref As %String, value As %String)
{
    Set pieces = 0
    For p=1:1000000:$Length(value) {
        Set pieces = pieces + 1
        Set @ref@(pieces) = $Extract(value, p, p + 999999)
    }
    Set @ref = pieces
}

ClassMethod GetLong(ref As %String) As %String
{
    Set out = ""
    For i=1:1:+$Get(@ref) {
        Set out = out_$Get(@ref@(i))
    }
    Quit out
}

}
