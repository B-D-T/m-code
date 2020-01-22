/* Reorders only the columns provided in the colsToReorder
The code inserts the listed columns in 
the beginning (inputPosOffset=0), 
the end (inputPosOffset=null/undefined), 
or anywhere in the middle (inputPosOffset=?).
*/

(inputTable as table, colsToReorder as list, optional inputPosOffset as nullable number) as table =>
	let
		listTableHeadingsOrig = Table.ColumnNames(inputTable),

		// If inputPosOffset is null/undefined, the columns are moved to the end. Otherwise, we insert the columns at the position (where 0 is the first position)
		posOffsetAdj = try inputPosOffset otherwise null,
		posOffset = if posOffsetAdj = null then ( List.Count(listTableHeadingsOrig) - List.Count(colsToReorder) ) else posOffsetAdj,

		// Return only the headings that AREN'T being reordered
		listDiff = List.Difference(listTableHeadingsOrig, colsToReorder),

		// Add the moving headings back into the list where they belong
		listInsRng = List.InsertRange(listDiff, posOffset, colsToReorder),

		// Reorder the table
		ReorderedTable = Table.ReorderColumns(inputTable, listInsRng)
	in
		ReorderedTable