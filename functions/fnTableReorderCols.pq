// fnTableReorderCols

// Reorders only the columns provided in the colsToReorder
// The code inserts the listed columns in 
// the beginning (inputPosOffset=0), 
// the end (inputPosOffset=null/undefined), 
// or anywhere in the middle (inputPosOffset=?, where ? is a column position integer).


(inputTable as table, colsToReorder as list, optional inputPosOffset as nullable number) as table =>
	let
		listTableHeadingsOrig = Table.ColumnNames(inputTable),

		// Remove any fields that are NOT in the original data table.
		// E.g., if I tell the code to move the "LastName" column, but the "LastName" column doesn't exist, that column will just be ignored.
		listOrderOfColsBeingMoved = List.Select(colsToReorder, each List.Contains(listTableHeadingsOrig, _)),  

		// If inputPosOffset is null/undefined, the columns are moved to the end. Otherwise, we insert the columns at the position (where 0 is the first position)
		posOffsetAdj = try inputPosOffset otherwise null,
		posOffset = if posOffsetAdj = null then ( List.Count(listTableHeadingsOrig) - List.Count(listOrderOfColsBeingMoved) ) else posOffsetAdj,

		// Return only the headings that AREN'T being reordered
		listHeadingsNOTMoving = List.Difference(listTableHeadingsOrig, listOrderOfColsBeingMoved),

		// Add the moving headings back into the list where they belong
		listInsRng = List.InsertRange(listHeadingsNOTMoving, posOffset, listOrderOfColsBeingMoved),

		// Reorder the table
		ReorderedTable = Table.ReorderColumns(inputTable, listInsRng)
	in
		ReorderedTable