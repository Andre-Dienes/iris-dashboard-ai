/// Data catalog of the namespace: schemas, tables, views, columns and relationships.
///
/// The compact text produced by SchemaText() is the context the LLM receives to write SQL
/// with correct JOINs. Relationships come from two sources in the class dictionary:
///   - declared FOREIGN KEYs (DDL or ForeignKey in classes)
///   - properties that reference persistent classes (Customer As Core.Customer)
///
/// Which schemas are visible:
///   - system/application schemas in HIDDENPREFIXES are never shown
///   - HIDDEN_SCHEMAS (config/env): extra comma-separated prefixes to hide
///   - VISIBLE_SCHEMAS (config/env): when set, ONLY these schemas are shown (allow-list)
Class Copilot.Core.Schema Extends %RegisteredObject
{

/// Prefixes of system/application schemas that are never exposed.
Parameter HIDDENPREFIXES = "%,INFORMATION_SCHEMA,Ens,EnsLib,Ens_,EnsLib_,HS_,HSMOD,HSFHIR,HSAA,Copilot_,IRIS_,SchemaMap,ISC_,DeepSee,Security,Config,SYS";

ClassMethod IsHidden(schema As %String) As %Boolean
{
    Set visible = ##class(Copilot.Core.Config).Get("VISIBLE_SCHEMAS")
    If visible'="" {
        Set viewSchema = ##class(Copilot.Core.Config).ViewSchema()
        Quit:$ZConvert(schema, "U")=$ZConvert(viewSchema, "U") 0
        Quit '$ListFind(..SchemaFilter(visible), $ZConvert(schema, "U"))
    }
    Set prefixes = ..#HIDDENPREFIXES_","_##class(Copilot.Core.Config).Get("HIDDEN_SCHEMAS")
    For i=1:1:$Length(prefixes, ",") {
        Set p = $ZStrip($Piece(prefixes, ",", i), "<>W")
        Continue:p=""
        Return:$ZConvert($Extract(schema, 1, $Length(p)), "U")=$ZConvert(p, "U") 1
    }
    Quit 0
}

/// [{"schema","tables","views"}]
ClassMethod ListSchemas() As %DynamicArray
{
    Set out = []
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(TABLE_SCHEMA) AS TABLE_SCHEMA, %EXACT(TABLE_TYPE) AS TABLE_TYPE, COUNT(*) AS N FROM INFORMATION_SCHEMA.TABLES GROUP BY %EXACT(TABLE_SCHEMA), %EXACT(TABLE_TYPE)")
    While rs.%Next() {
        Set schema = rs.%Get("TABLE_SCHEMA")
        Continue:..IsHidden(schema)
        Set type = rs.%Get("TABLE_TYPE")
        Continue:(type'="BASE TABLE")&&(type'="VIEW")
        Set count(schema, type) = rs.%Get("N")
    }
    Set schema = ""
    For {
        Set schema = $Order(count(schema))
        Quit:schema=""
        Do out.%Push({"schema": (schema), "tables": (+$Get(count(schema, "BASE TABLE"))), "views": (+$Get(count(schema, "VIEW")))})
    }
    Quit out
}

/// Detailed catalog of the given schemas (comma-separated list; "" = all visible schemas).
/// [{"schema","name","fullName","type","description","columns":[{name,type,description,pk,ref}]}]
ClassMethod Catalog(schemas As %String = "") As %DynamicArray
{
    Set filter = ..SchemaFilter(schemas)
    Set out = [], index = {}
    Set sql = "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, CLASSNAME, DESCRIPTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE IN ('BASE TABLE','VIEW') ORDER BY TABLE_SCHEMA, TABLE_NAME"
    Set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    If rs.%SQLCODE<0 {
        // versions without CLASSNAME/DESCRIPTION
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, NULL AS CLASSNAME, NULL AS DESCRIPTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE IN ('BASE TABLE','VIEW') ORDER BY TABLE_SCHEMA, TABLE_NAME")
    }
    While rs.%Next() {
        Set schema = rs.%Get("TABLE_SCHEMA")
        Continue:..IsHidden(schema)
        Continue:(filter'="")&&'$ListFind(filter, $ZConvert(schema, "U"))
        Set name = rs.%Get("TABLE_NAME"), full = schema_"."_name
        Set table = {"schema": (schema), "name": (name), "fullName": (full), "type": ($Select(rs.%Get("TABLE_TYPE")="VIEW":"view", 1:"table")), "className": (rs.%Get("CLASSNAME")), "description": (..CleanText(rs.%Get("DESCRIPTION"))), "columns": []}
        Do out.%Push(table)
        Do index.%Set($ZConvert(full, "U"), table)
    }
    Quit:out.%Size()=0 out

    // columns
    Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, DESCRIPTION, PRIMARY_KEY FROM INFORMATION_SCHEMA.COLUMNS ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION")
    If rs.%SQLCODE<0 {
        Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, NULL AS DESCRIPTION, NULL AS PRIMARY_KEY FROM INFORMATION_SCHEMA.COLUMNS ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION")
    }
    While rs.%Next() {
        Set table = index.%Get($ZConvert(rs.%Get("TABLE_SCHEMA")_"."_rs.%Get("TABLE_NAME"), "U"))
        Continue:'$IsObject(table)
        Set col = rs.%Get("COLUMN_NAME")
        Continue:col["x__"
        Do table.columns.%Push({"name": (col), "type": ($ZConvert(rs.%Get("DATA_TYPE"), "U")), "description": (..CleanText(rs.%Get("DESCRIPTION"))), "pk": ($Select(rs.%Get("PRIMARY_KEY")="YES":1, 1:0))})
    }

    // relationships (class dictionary)
    Set iter = out.%GetIterator()
    While iter.%GetNext(, .table) {
        Continue:(table.type'="table")||(table.className="")
        Do ..AddReferences(table)
    }
    // optional catalog plugin (CATALOG_HOOK = class name): may enrich descriptions/relationships,
    // e.g. for tables that come from other systems
    Set hook = ##class(Copilot.Core.Config).Get("CATALOG_HOOK")
    Do:hook'="" $ClassMethod(hook, "EnrichCatalog", out)
    Quit out
}

/// Fills col.ref = "Schema.Table.Column" from foreign keys and object references.
ClassMethod AddReferences(table As %DynamicObject)
{
    Set cls = ##class(%Dictionary.CompiledClass).%OpenId(table.className, 0)
    Quit:'$IsObject(cls)
    Set refs = {}
    // 1) foreign keys
    For i=1:1:cls.ForeignKeys.Count() {
        Set fk = cls.ForeignKeys.GetAt(i)
        Set target = ##class(%Dictionary.CompiledClass).%OpenId(fk.ReferencedClass, 0)
        Continue:'$IsObject(target)
        Set targetTable = target.SqlSchemaName_"."_target.SqlTableName
        Set targetCols = ..KeyColumns(target, fk.ReferencedKey)
        For p=1:1:$Length(fk.Properties, ",") {
            Set prop = $ZStrip($Piece(fk.Properties, ",", p), "<>W")
            Set field = ..FieldName(cls, prop)
            Set targetCol = $Piece(targetCols, ",", p)
            Set:targetCol="" targetCol = $Select(target.SqlRowIdName'="":target.SqlRowIdName, 1:"ID")
            Do refs.%Set($ZConvert(field, "U"), targetTable_"."_targetCol)
        }
    }
    // 2) properties that reference persistent classes
    For i=1:1:cls.Properties.Count() {
        Set prop = cls.Properties.GetAt(i)
        Continue:prop.Collection'=""
        Continue:prop.Relationship&&(prop.Cardinality'="one")&&(prop.Cardinality'="parent")
        Continue:$Extract(prop.Type)="%"
        Set target = ##class(%Dictionary.CompiledClass).%OpenId(prop.Type, 0)
        Continue:'$IsObject(target)
        Continue:target.ClassType'="persistent"
        Set field = $Select(prop.SqlFieldName'="":prop.SqlFieldName, 1:prop.Name)
        Continue:refs.%IsDefined($ZConvert(field, "U"))
        Do refs.%Set($ZConvert(field, "U"), target.SqlSchemaName_"."_target.SqlTableName_"."_$Select(target.SqlRowIdName'="":target.SqlRowIdName, 1:"ID"))
    }
    Set iter = table.columns.%GetIterator()
    While iter.%GetNext(, .col) {
        Set ref = refs.%Get($ZConvert(col.name, "U"))
        Do:ref'="" col.%Set("ref", ref)
    }
}

ClassMethod FieldName(cls As %Dictionary.CompiledClass, propName As %String) As %String
{
    For i=1:1:cls.Properties.Count() {
        Set prop = cls.Properties.GetAt(i)
        Return:prop.Name=propName $Select(prop.SqlFieldName'="":prop.SqlFieldName, 1:prop.Name)
    }
    Quit propName
}

/// SQL columns of the referenced index/key; "" when it is the default IDKEY.
ClassMethod KeyColumns(cls As %Dictionary.CompiledClass, keyName As %String) As %String
{
    Quit:keyName="" ""
    For i=1:1:cls.Indices.Count() {
        Set idx = cls.Indices.GetAt(i)
        Continue:idx.Name'=keyName
        Set out = ""
        For p=1:1:$Length(idx.Properties, ",") {
            Set prop = $Piece($ZStrip($Piece(idx.Properties, ",", p), "<>W"), ":")
            Set out = out_$Select(out="":"", 1:",")_..FieldName(cls, prop)
        }
        Return out
    }
    Quit ""
}

/// Compact context for the LLM: today's date, business glossary and catalog.
ClassMethod SchemaText(schemas As %String = "", withSamples As %Boolean = 1, withGlossary As %Boolean = 1) As %String
{
    Set catalog = ..Catalog(schemas)
    Set max = ##class(Copilot.Core.Config).MaxSchemaChars()
    // privacy mode: no data values in the context, metadata only
    Set:##class(Copilot.Core.Config).PrivacyMode() withSamples = 0
    Set out = "", nl = $Char(10)
    If withGlossary {
        // the LLM does not know today's date: without this it guesses the month/year of relative periods
        Set months = $ListBuild("January","February","March","April","May","June","July","August","September","October","November","December")
        Set today = +$Horolog, month = +$Piece($ZDate(today, 3), "-", 2), year = +$Piece($ZDate(today, 3), "-", 1)
        Set prev = $Select(month=1:12, 1:month - 1), prevYear = $Select(month=1:year - 1, 1:year)
        Set out = "TODAY (IRIS server date): "_$ZDate(today, 3)_". Current month: "_$List(months, month)_" "_year_
            ". Previous month: "_$List(months, prev)_" "_prevYear_". Use these dates when explaining periods; never assume another year."_nl_nl
        // only the glossary terms of the schemas in this catalog
        Set inScope = "", iterS = catalog.%GetIterator()
        While iterS.%GetNext(, .tbl) {
            Set:'$ListFind(inScope, $ZConvert(tbl.schema, "U")) inScope = inScope_$ListBuild($ZConvert(tbl.schema, "U"))
        }
        Set glossary = ##class(Copilot.Data.Glossary).PromptText($Select(inScope'="":inScope, 1:$ListBuild("")))
        Set:glossary'="" out = out_glossary_nl
    }
    Set iter = catalog.%GetIterator()
    While iter.%GetNext(, .table) {
        Set block = $Select(table.type="view":"VIEW ", 1:"TABLE ")_table.fullName
        Set:table.description'="" block = block_"  -- "_table.description
        Set block = block_nl
        Set cols = table.columns.%GetIterator()
        While cols.%GetNext(, .col) {
            Set line = "  "_col.name_" "_col.type
            Set:col.pk line = line_" PK"
            Set:col.%Get("ref")'="" line = line_" -> "_col.ref
            Set:col.description'="" line = line_"  -- "_col.description
            If withSamples, '..SkipSamples(table.fullName), ($Length(out) < (max * 0.7)), (col.type["CHAR") {
                Set samples = ..SampleValues(table.fullName, col.name)
                Set:samples'="" line = line_"  [values: "_samples_"]"
            }
            Set block = block_line_nl
        }
        If $Length(out) + $Length(block) > max {
            Set out = out_"... (catalog truncated: "_(catalog.%Size())_" tables in total; narrow the schemas)"_nl
            Quit
        }
        Set out = out_block
    }
    Quit out
}

/// The catalog plugin (CATALOG_HOOK) may skip sample values for some tables (e.g. slow remote tables).
ClassMethod SkipSamples(table As %String) As %Boolean
{
    Set hook = ##class(Copilot.Core.Config).Get("CATALOG_HOOK")
    Quit:hook="" 0
    Quit +$ClassMethod(hook, "SkipSamples", table)
}

/// Distinct values of low-cardinality columns (up to 12), cached.
ClassMethod SampleValues(table As %String, column As %String) As %String
{
    If $Data(^Copilot.Cache("values", table, column), cached) Quit cached
    Set out = ""
    Try {
        Set q = """"
        Set sql = "SELECT DISTINCT TOP 13 %EXACT("_q_column_q_") AS V FROM "_..QuoteTable(table)_" WHERE "_q_column_q_" IS NOT NULL"
        Set stmt = ##class(%SQL.Statement).%New()
        Set stmt.%SelectMode = 1
        Quit:$$$ISERR(stmt.%Prepare(sql))
        Set rs = stmt.%Execute(), n = 0, list = ""
        While rs.%Next() {
            Set n = n + 1, v = rs.%Get("V")
            Set list = list_$ListBuild(v)
            If (n > 12) || ($Length(v) > 40) {
                Set list = ""
                Quit
            }
        }
        For i=1:1:$ListLength(list) {
            Set out = out_$Select(i=1:"", 1:", ")_"'"_$List(list, i)_"'"
        }
    } Catch {
        Set out = ""
    }
    Set ^Copilot.Cache("values", table, column) = out
    Quit out
}

ClassMethod QuoteTable(table As %String) As %String
{
    Quit """"_$Piece(table, ".", 1)_"""."""_$Piece(table, ".", 2, *)_""""
}

/// Clears caches (sample values).
ClassMethod Refresh() As %Status
{
    Kill ^Copilot.Cache
    Quit $$$OK
}

ClassMethod SchemaFilter(schemas As %String) As %List
{
    Set list = ""
    For i=1:1:$Length(schemas, ",") {
        Set s = $ZStrip($Piece(schemas, ",", i), "<>W")
        Set:s'="" list = list_$ListBuild($ZConvert(s, "U"))
    }
    Quit list
}

ClassMethod CleanText(text As %String) As %String
{
    Quit $ZStrip($Translate(text, $Char(13,10,9), "   "), "<>=W")
}

}
