// This returns the value for a given key within a parameter definition table

let
fn =
    (
        strKeyName as text,
        optional strDataType as text, // Enumeration: text [default], number, datetime, logical
        optional blnReturnList as logical,
        optional strParameterTableName as text,
        optional strKeyFieldName as text,
        optional strValueFieldName as text
    ) =>

    let
        // Set default values for the optional parameters
        strDataType = if strDataType <> null then Text.Lower(strDataType) else "text",
        blnReturnList = if blnReturnList <> null then blnReturnList else false,
        strParameterTableName = if strParameterTableName <> null then strParameterTableName else "tblParameters",
        strKeyFieldName = if strKeyFieldName <> null then strKeyFieldName else "ParameterKey",
        strValueFieldName = if strValueFieldName <> null then strValueFieldName else "ParameterValue",

        // Pull the Parameters table into the function
        Source = Excel.CurrentWorkbook(){[Name=strParameterTableName]}[Content],

        // Reference the key and return the value
        ParamRow = Table.SelectRows(Source, each (Table.Column(_, strKeyFieldName) = strKeyName)),
        strVariableValue = if Table.IsEmpty(ParamRow)=true then null else Text.From(Record.Field(ParamRow{0}, strValueFieldName)),

        // This will accept M types or Cypher types
        fConvertData = (strValue as text, strDataType as text) =>
            let
                NewValue = 
                if List.Contains({"number", "toFloat", "toInteger"}, strDataType) then Number.From(strValue) else
                if List.Contains({"date"}, strDataType) then Date.From(strValue) else 
                if List.Contains({"datetime"}, strDataType) then DateTime.From(strValue) else 
                if List.Contains({"logical", "toBoolean"}, strDataType) then Logical.From(strValue) else
                Text.From(strValue)
            in
                NewValue,

        SetOutputType = 
            if blnReturnList = false
            then fConvertData(strVariableValue, strDataType)
            else // is a list 
            (if strVariableValue is null then {} else
                let 
                    ListAsText = Text.Split(Text.From(strVariableValue), ", "),
                    ConvertListData = List.Transform(ListAsText, each fConvertData(_, strDataType))
                in
                        ConvertListData
            )
    in
        SetOutputType,

fnType = type function
    (
        strKeyName as text,
        optional strDataType as text,
        optional blnReturnList as (type logical meta [ Documentation.AllowedValues = {true, false}]),
        optional strParameterTableName as text,
        optional strKeyFieldName as text,
        optional strValueFieldName as text
    ) as list meta
        [
            Documentation.Name = "fnGetParam",
            Documentation.LongDescription = "Returns the value for a given key within a parameter definition table. This returns a text string by default. If you want it to return a number or a list, use the correct arguments.
            Defaults: (none), ""text"", false, ""tblParameters"", ""ParameterKey"", ""ParameterValue"")",
            Documentation.Examples = 
                {
                    [
                        Description = "Look in the ParameterValue column of tblParameters. Return [as a list of numbers] the cell value where CourseCRNs is in the same row in the ParameterKey column.",
                        Code = "fnGetParam(""CourseCRNs"", ""number"", true, ""tblParameters"", ""ParameterKey"", ""ParameterValue"")",
                        Result = "{80140, 80224}"
                    ],
                    [
                        Description = "This is the same as the example above, but with using the default parameters. The result is the same data as a single text string.",
                        Code = "fnGetParam(""CourseCRNs"")",
                        Result = """80140, 80224"""
                    ]
                }
        ]
in
    Value.ReplaceType( 
        fn, fnType
    )
