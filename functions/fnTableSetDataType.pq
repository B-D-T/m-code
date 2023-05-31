// fnTableSetDataType

// Converts the specific columns of a table to the given data type and returns that table
// This function works for a single data type. If you want to convert lists of columns to different data types, nest this function within some new function.

let

fn =
    (
		paramTable as table,
		optional paramColNames as list,
		optional paramDataType as type // Can write this as 'type number' or 'Number.Type' in code
    ) =>

    let
		// Default to Text data if not specified otherwise
		inputTable = paramTable,
		inputColNames = if List.Contains({null, "", " "}, paramColNames) then Table.ColumnNames(inputTable) else paramColNames,
		inputDataType = if List.Contains({null, "", " "}, paramDataType) then Text.Type else paramDataType, 

        // Remove any columns that aren't in the table
        colsToConvert = List.Intersect({inputColNames, Table.ColumnNames(inputTable)}),

		// Create a list of list-pairs that have each column and the data type that it should be. E.g., { {"ColA", type number}, {"ColB", type number} }		
		listColTransformations = List.Transform(
				colsToConvert,
				each {_, inputDataType}
			),
		// Transform the column types in the focal table based on the transformation list defined in the step above (listColTransformations)
		TransformedTable = Table.TransformColumnTypes(inputTable, listColTransformations)
	in
		TransformedTable,

fnType = type function
    (
		paramTable as table,
		optional paramColNames as list,
		optional paramDataType as type 
    ) as list meta
        [
            Documentation.Name = "fnTableSetDataType",
            Documentation.LongDescription = "Returns a table that's the same as the input table except the specific columns have been converted to the specified data type. If the 3rd parameter (Date Type) is null, the Text data type will be used. If the 2nd parameter (the list of columns) is null, all the columns in the table will be used.",
            Documentation.Examples = 
                {
                    [
                        Description = "This will change the CategoryNum, FilterNum, and Value columns in the 'Source' table to be columns of the Number data type.",
                        Code = "fnTableSetDataType(Source, {""CategoryNum"", ""FilterNum"", ""Value""}, type number)",
                        Result = "A table with the data types changed to Number for the 3 columns."
                    ],
                    [
                        Description = "This will do the same as the example above using the built-in M function. There's no difference in the output between this table and the one in the first example.",
                        Code = "Table.TransformColumnTypes(Source,{{""CategoryNum"", type number}, {""FilterNum"", type number}, {""Value"", type number} })",
                        Result = "The same table as produced using the fnTableSetDataType function."
                    ],
                    [
                        Description = "This will change all the columns in the 'Source' table to be columns of the Text data type.",
                        Code = "fnTableSetDataType(Source)",
                        Result = "A table where all the columns are set as Text."
                    ]
                }
        ]
in
    Value.ReplaceType( 
        fn, fnType
    )
