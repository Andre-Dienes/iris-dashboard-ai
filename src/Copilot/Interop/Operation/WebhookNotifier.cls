/// Webhook Notifier - business operation that posts report/alert notifications to external systems
/// (Microsoft Teams / Slack incoming webhooks, ticketing, automation tools).
Class Copilot.Interop.Operation.WebhookNotifier Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

/// SSL/TLS configuration used for https URLs (created on demand).
Property SSLConfig As %String [ InitialExpression = "COPILOT_TLS" ];

Parameter SETTINGS = "SSLConfig:Connection";

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Copilot.Interop.Msg.WebhookRequest">
    <Method>Notify</Method>
  </MapItem>
</MapItems>
}

Method Notify(request As Copilot.Interop.Msg.WebhookRequest, Output response As Ens.Response) As %Status
{
    Set sc = $$$OK
    Try {
        Do ##class(%Net.URLParser).Decompose(request.URL, .url)
        Set http = ##class(%Net.HttpRequest).%New()
        Set http.Server = url("host")
        Set http.Https = ($ZConvert(url("scheme"), "L")="https")
        Set http.Port = $Select($Get(url("port"))'="":url("port"), http.Https:443, 1:80)
        Set:http.Https http.SSLConfiguration = ..EnsureSSL()
        Set http.Timeout = 30
        Set http.ContentType = "application/json; charset=utf-8"
        Do http.EntityBody.Write($ZConvert(request.Payload, "O", "UTF8"))
        Set path = $Get(url("path"), "/")
        Set:$Get(url("query"))'="" path = path_"?"_url("query")
        $$$ThrowOnError(http.Post(path))
        If http.HttpResponse.StatusCode>=300 {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Webhook HTTP "_http.HttpResponse.StatusCode))
        }
    } Catch ex {
        Set sc = ex.AsStatus()
    }
    Quit sc
}

Method EnsureSSL() As %String
{
    Set name = ..SSLConfig
    New $Namespace
    Set $Namespace = "%SYS"
    Do:'##class(Security.SSLConfigs).Exists(name) ##class(Security.SSLConfigs).Create(name)
    Quit name
}

}
