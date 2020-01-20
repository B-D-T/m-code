//LibPQ("fnTableSetDataTypeCypher")
// Changes column types given Cypher conversion statements, which can be in the first row of the table 

// This accepts a list of transformation statements (in Cypher) as the inputDataTypeListCypher argument.
//      e.g., inputDataTypeListCypher = {"toString", "toFloat", "date", "toString"}
// That number of items in that list should match the number of column headers in the inputTable. Any null values will be treated as toString.
// The presence of inputDataTypeListCypher means that the first row in the table is data (i.e., the normal situation)

// If there is no second argument, the code assumes that the transformation statements are in the first row of the table.
// It reads that row, deletes it, and returns the data table WITHOUT the first row.


(inputTable as table, optional inputDataTypeListCypher as list) as table =>
    let
        // inputTable = Excel.CurrentWorkbook(){[Name="tblCreateNodes"]}[Content], inputDataTypeListCypher = null, //Testing

        // This reads the first row of the table to get the data types (if necessary)
		blnInputDataTypeListCypher = try inputDataTypeListCypher is list otherwise false,
        listDataTypeRowInitial = if blnInputDataTypeListCypher then inputDataTypeListCypher else Record.ToList(inputTable{0}),
		
        tblDataTypesM = LibPQ("tblDataTypesM"),

        // As an error check, look at the input list of Cypher conversion statements.
        // If any of the items are NOT valid Cypher conversions or are null, use toString instead.
		fnListSetDataTypeCypherConversions = LibPQ("fnListSetDataTypeCypherConversions"),
		numTableColumns = List.Count( Table.ColumnNames(inputTable) ),
		listConversionStatementRow = fnListSetDataTypeCypherConversions(listDataTypeRowInitial, numTableColumns),

        // Look up the corresponding M data types (as types) based on the Cypher conversion text strings
		tblConversionStatements = Table.FromList(listConversionStatementRow , null, {"CypherConversion"} ),
        // The subsequent merge step can put this out of order. Adding the index allows us to get it back the way it belongs.
        tblConversionStatementsInOrder = Table.AddIndexColumn(tblConversionStatements, "SortIndex", 1, 1),
        MergedWithTblDataTypes = Table.NestedJoin(tblConversionStatementsInOrder, {"CypherConversion"} , tblDataTypesM, {"CypherConversion"}, "ConversionTable" , JoinKind.Inner ),
        AddedMDataTypes = Table.AddColumn(MergedWithTblDataTypes, "DataTypeM", each [ConversionTable][DTdotType]{0}, type type),
        SortedConversionDataTypeTable = Table.Sort(AddedMDataTypes, {"SortIndex" , Order.Ascending} ),
		
        // The list of data types. E.g., {type text, type number}
        listDataTypes = SortedConversionDataTypeTable[DataTypeM],

        // Remove the first row from the original table if necessary (i.e., the row with the data type conversion instructions)
        TableToConvert = if blnInputDataTypeListCypher then inputTable else Table.Skip(inputTable,1),
		
        // A list of lists. Each item in the outer list has two rows: The column name and the M data type. E.g., { {"Name", type text}, {"IDNum", type number} }
        listConversionZipper = List.Zip({ Table.ColumnNames(TableToConvert) , listDataTypes }),

        // The properly typed data table
        ChangedTable = Table.TransformColumnTypes(TableToConvert, listConversionZipper )
        
    in
        ChangedTable