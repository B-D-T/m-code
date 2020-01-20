// Converts the specific columns of a table to the given data types

( inputTable as table, inputCols as list, inputDataTypes as type) =>
let
	
	listColTransformations = List.Transform(
		inputCols,
        each {_, inputDataTypes}
    ),
	TransformedTable = Table.TransformColumnTypes(inputTable, listColTransformations)
in
	TransformedTable
