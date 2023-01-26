// fnTableSetDataTypesManual

// Received a list of lists. Each item is a 2-element list describing the conversion (e.g., { {"id", Int64.Type}, {"FirstName", type text} } ).
// Converts the columns of a table to the given data type, but only if that column is in the table.
// Returns the table

let

fn =
    (
		paramTable as table,
		paramTransformations as list // {{field_name as text, type as type}}
    ) =>

    let
	
		manualTypeTransformations = paramTransformations,
		manualTypeTransformationsInTable = List.Select(manualTypeTransformations, each Table.HasColumns(paramTable, _{0}))
	in
		Table.TransformColumnTypes(paramTable, manualTypeTransformationsInTable),


fnType = type function
    (
		paramTable as table,
		paramTransformations as list 
    ) as list meta
        [
            Documentation.Name = "fnTableSetDataTypesManual",
            Documentation.LongDescription = "Converts the columns of a table to the given data type, but only if that column is in the table. Pass a list of lists. Each item is a 2-element list describing the conversion (i.e., {{field_name as text, type as type}}).",
            Documentation.Examples = 
                {
                    [
                        Description = "This will change ""id"" to an integer ""FirstName"" to text.",
                        Code = "fnTableSetDataTypesManual(Source, { {""id"", Int64.Type}, {""FirstName"", type text} })",
                        Result = "A table with the data types changed."
                    ]
                }
        ]
in
    Value.ReplaceType( 
        fn, fnType
    )