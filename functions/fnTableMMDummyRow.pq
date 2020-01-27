/* The mail merge reads the first 8-15 rows of data to determine what it needs to pull. 
To prevent truncated fields, I created a row that has cells with 256 characters for any text-formatted columns.

Any field name in "sortFields" will have "AAAAA" to help with sorting.

*/

(inputTable as table, optional sortFields as list) as table =>
let
    LogTableSchema = Table.Schema(inputTable),
    DummyCol = Table.AddColumn(LogTableSchema, "Value", each if [Position]=0 then 0 else 
        if List.Contains(sortFields, [Name]) then "AAAAA" else
        if [Kind] ="text" then Text.Repeat("|",256) else null),
    AddedDummyRow = Table.InsertRows(
		inputTable,
		0,
		{Record.FromTable(
			Table.SelectColumns(
				DummyCol,
				{"Name", "Value"}
			)
		)}
	)
in
	AddedDummyRow