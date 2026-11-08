Include %AI

/// Data Analyst tools (%AI.ToolSet). The agent decides which ones to call to explore the catalog
/// and query the database. They are also exposed to MCP clients at /mcp/copilot.
/// All tools are read-only and run with the SQL privileges of the signed-in IRIS user.
Class Copilot.AI.Tools Extends %AI.ToolSet
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="CopilotDataTools">
  <Description>Read-only exploration and querying of InterSystems IRIS data: schemas, tables, columns, relationships and SELECT execution.</Description>
  <Tool Name="ListSchemas" Method="ListSchemas">
    <Description>Lists the available SQL schemas with their number of tables and views.</Description>
  </Tool>
  <Tool Name="ListTables" Method="ListTables">
    <Description>Lists the tables and views of a schema with their description. Pass schema (e.g. Sales).</Description>
  </Tool>
  <Tool Name="DescribeTable" Method="DescribeTable">
    <Description>Shows the columns, types, primary key, relationships (column -> Schema.Table.Column) and sample values of a table. Pass table as Schema.Table.</Description>
  </Tool>
  <Tool Name="RunQuery" Method="RunQuery">
    <Description>Runs a read-only SELECT in the IRIS SQL dialect (use TOP n, never LIMIT) and returns up to 50 rows as markdown. Pass sql.</Description>
  </Tool>
</ToolSet>
}

ClassMethod ListSchemas() As %String
{
    Quit ##class(Copilot.Core.Schema).ListSchemas().%ToJSON()
}

ClassMethod ListTables(schema As %String) As %String
{
    Set out = [], iter = ##class(Copilot.Core.Schema).Catalog(schema).%GetIterator()
    While iter.%GetNext(, .t) {
        Do out.%Push({"table": (t.fullName), "type": (t.type), "description": (t.description), "columns": (t.columns.%Size())})
    }
    Quit:out.%Size()=0 "No tables found in schema "_schema_". Use ListSchemas."
    Quit out.%ToJSON()
}

ClassMethod DescribeTable(table As %String) As %String
{
    Set schema = $Piece(table, "."), name = $Piece(table, ".", 2, *)
    Set text = ##class(Copilot.Core.Schema).SchemaText(schema, 1, 0)
    // keep only the block of the requested table
    Set nl = $Char(10), out = "", inside = 0
    For i=1:1:$Length(text, nl) {
        Set line = $Piece(text, nl, i)
        If $Extract(line)'=" " {
            Set head = $Piece($Piece(line, "  --"), " ", 2)
            Set inside = ($ZConvert(head, "U")=$ZConvert(schema_"."_name, "U"))
        }
        Set:inside out = out_line_nl
    }
    Quit:out="" "Table "_table_" not found. Use ListTables(schema)."
    Quit out
}

ClassMethod RunQuery(sql As %String) As %String
{
    Try {
        Set out = ##class(Copilot.Core.SQL).RunMarkdown(sql, 50)
        // remember the executed queries so the UI can offer chart/dashboard actions
        Set %CopilotAgentSQL($Increment(%CopilotAgentSQL)) = sql
    } Catch ex {
        Set out = "ERROR: "_$Replace(ex.DisplayString(), "ERROR #5001: ", "")_$Char(10)_"Fix the query (IRIS dialect: TOP n, DATEPART, TO_CHAR(CAST(d AS DATE),'YYYY-MM')) and try again."
    }
    Quit out
}

}
