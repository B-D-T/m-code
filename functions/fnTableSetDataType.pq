
( inputTable as table, inputCols as list, inputDataType as type) =>
let
	listColTransformations = List.Transform(
		inputCols,
        each {_, inputDataType}
    ),
	TransformedTable = Table.TransformColumnTypes(inputTable, listColTransformations)
in
	TransformedTable