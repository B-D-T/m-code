// Data types in Power Query
// This table can help with conversions.

#table(
type table
    [
        #"DataTypeTerm" = text,
        #"DTdotType" = type,
        #"TypeDT" = type,
		#"CypherConversion" = text
	],
 {
	{ "Integer", Int64.Type, null , "toInteger" },
	{ "Int64", Int64.Type, null , "toInteger" },
	{ "Number", Number.Type, type number , "toFloat" },
	{ "Date", Date.Type, type date , "date" },
	{ "Text", Text.Type, type text , "toString" },
	{ "String", Text.Type, type text , "toString" },
	{ "Binary", Binary.Type, type binary , null},
	{ "DateTime", DateTime.Type, type datetime , "datetime" },
	{ "DateTimeTimezone", DateTimeZone.Type, type datetimezone , null },
	{ "Duration", Duration.Type, type duration , null },
	{ "Function", Function.Type, type function , null },
	{ "List", List.Type, type list , null },
	{ "Logical", Logical.Type, type logical , "toBoolean" },
	{ "Boolean", Logical.Type, type logical , "toBoolean" },
	{ "TrueFalse", Logical.Type, type logical , "toBoolean" },
	{ "Record", Record.Type, type record , null },
	{ "Any", Any.Type, type any , "toString" },
	{ "AnyNonNull", null, type anynonnull , null},
	{ "None", None.Type, type none , null},
	{ "Null", Null.Type, type null , null},
	{ "Type", Type.Type, type type , null}
 }
)
