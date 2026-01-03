// fnReadTableTypes  
// Reads the column names and types from a table and returns them in various formats
// Requires: fnReadColType

let 

docstring_main_func = [
    Documentation.Name = "fnReadTableTypes",
    Documentation.Description = "Reads the non-null values from each column in a table to guess the data type of each column based on its values. Returns the results as list, record, tableWide, or tableTall.",
    Documentation.Author = "B. David Tyler",
    Documentation.Version = "0.0.1"
],

docstring_param_tbl = [
    Documentation.FieldCaption = "Table with columns analyze"
],

docstring_param_returnFormat = [
    Documentation.FieldCaption = "Return format for the report of column types",
    Documentation.FieldDescription = "Specifies the format in which the column types are returned. Options include 'list', 'record', 'tableWide', and 'tableTall'. Default is 'list'.",
    Documentation.LongDescription = "This parameter allows the user to specify how they would like the column types of the input table to be returned. Options: 
        'list' (default): A list of lists, where each item is a {column name, column type} pair.
        'record': A record where field names are column names and field values are column types.
        'tableWide': A single-row table where column names are column names and values are column types.
        'tableTall': A two-column table with columns 'ColumnName' and 'ColumnType'.",
    Documentation.AllowedValues = {"list", "record", "tableWide", "tableTall"},
    Formatting.IsCode = false
],

// Documentation for the main function - this replaces the type information for the function to show type hints in the Power Query Editor
docstring = type function (
    tbl as (type table meta docstring_param_tbl),
    optional returnFormat as (type nullable text meta docstring_param_returnFormat)
    ) as any
    meta docstring_main_func,

fnReadTableTypes_INIT = (tbl as table, optional returnFormat as nullable text) as any =>
    let
        // tbl = tblDaysOfTheWeek,
        // returnFormat = null,
        colNames = Table.ColumnNames(tbl),
        colTypes = List.Transform(
            colNames,
            each fnReadColType(Table.Column(tbl, _))
        ),

        mapperList = List.Zip({colNames, colTypes}),
        mapperRecords = Record.FromList(colTypes, colNames),
        mapperTableWide = Table.FromRecords({mapperRecords}),
        mapperTableTall = Table.FromColumns(
            {colNames, colTypes},
            {"ColumnName", "ColumnType"}
        ),
        result = 
            if List.Contains({"list", "lists", null}, returnFormat) then
                mapperList
            else if List.Contains({"record", "records"}, returnFormat) then
                mapperRecords
            else if returnFormat = "tableWide" then
                mapperTableWide
            else if List.Contains({"tableTall", "table"}, returnFormat) then
                mapperTableTall
            else
                error "Invalid return format specified."
        in
            result // end of main function body

in // end of full definition
    Value.ReplaceType(fnReadTableTypes_INIT, docstring)
