// fnFindCellLocOfValue.pq
// Returns the location of a value in an input table as a record with various address formats
// Row and column numbers are 1-based (i.e., first row is 1, first column is 1)
// (
//     inputTable as table,
//     valueToFind as any,
//     optional rowNumFilter as nullable number, // to speed up processing and limit false matches. Can be positive (top N rows) or negative (bottom N rows). However, even if negative, the search still moves left to right.
//     optional colNumFilter as nullable number // to speed up processing and limit false matches. Can be positive (first N columns) or negative (last N columns). However, even if negative, the search still moves top to bottom.
//     ) as record =>
let
    inputTable = 
        let
            _path = "C:\Users\btyler\OneDrive - University of Massachusetts\Teaching\Data\Courses\202508DataGrad\Assessments\Exam01\Original\Anya_Blount_Submission.xlsx",
            binGradedExcelWorkbook = File.Contents(_path),
            Source = Excel.Workbook(binGradedExcelWorkbook, null, true),
            wks = Source{[Item="SysEnvInfo4Excel",Kind="Sheet"]}[Data]
        in
            wks,
    valueToFind = "alphaUpper", // and strFileName
    rowNumFilter = null,
    colNumFilter = null,

    rowsFilter = if List.Contains({null, 0}, rowNumFilter) then null else rowNumFilter,
    colsFilter = if List.Contains({null, 0}, colNumFilter) then null else colNumFilter,

    #"---Add column names and row numbers ---" = "",

    numOfColsOrig = Table.ColumnCount(inputTable),
    colNamesOrig = Table.ColumnNames(inputTable),

    // Create a list of Column1, Column2, ..., ColumnN
    lstDummyColNames = List.Transform({1..numOfColsOrig}, each "Column" & Text.From(_)),
    // If starting without headers, the keys and values will be identical
    recDummyColNamesMap = Record.FromList(lstDummyColNames, colNamesOrig),

    InsertedDummyColNamesAsFirstRow = Table.InsertRows(
        inputTable,
        0,
        {recDummyColNamesMap}
    ),

    // The first row is now the column names (Column1, Column2, etc.), so our row index starts at 0
    AddedRowNumsToOrigSheet = Table.AddIndexColumn(InsertedDummyColNamesAsFirstRow, "ExcelRowNums", 0, 1, Int64.Type),

    // Move ExcelRowNums to be first column
    ReorderedColsWithRowNumsFirst = Table.ReorderColumns(
        AddedRowNumsToOrigSheet,
        List.Combine({
            {"ExcelRowNums"},
            List.RemoveItems(Table.ColumnNames(AddedRowNumsToOrigSheet), {"ExcelRowNums"})
        })
    ),

    TableBeforeFiltering = ReorderedColsWithRowNumsFirst,

    filteredRows = if rowsFilter = null then TableBeforeFiltering
        else if rowsFilter > 0 then Table.FirstN(TableBeforeFiltering, rowsFilter)
        else if rowsFilter < 0 then Table.LastN(TableBeforeFiltering, Number.Abs(rowsFilter))
        else TableBeforeFiltering,
    
    filteredCols = if colsFilter = null then filteredRows
        else if colsFilter > 0 then Table.SelectColumns(
            filteredRows,
            List.FirstN(Table.ColumnNames(filteredRows), colsFilter + 1) // +1 to account for ExcelRowNums column
            )
        else if colsFilter < 0 then Table.SelectColumns(
            filteredRows,
            List.Combine({
                {"ExcelRowNums"},
                List.LastN(Table.ColumnNames(filteredRows), Number.Abs(colsFilter))
            })
        )
        else filteredRows,

    BaseTableForFinds = filteredCols,

    #"---Find column with value ---" = "Find the column name/number of the value",
    startTableForColFind = BaseTableForFinds,

    SetColumnNamesAsRowAgainIfNecessary = 
        if rowsFilter = null then startTableForColFind
        else if rowsFilter < 0 then Table.DemoteHeaders(startTableForColFind)
        else startTableForColFind,

    TransposedTable = Table.Transpose(SetColumnNamesAsRowAgainIfNecessary),
    ChangeFieldNameToColNameOrig = Table.RenameColumns(TransposedTable,{{"Column1", "ColumnNameOrig"}}),

    // This step is necessary if rowsFilter is negative (i.e., we're looking toward the bottom)
    TableBeforeUnpivot = Table.SelectRows(ChangeFieldNameToColNameOrig, 
        each [ColumnNameOrig] <> "ExcelRowNums"),

    // This also removes nulls, shrinking the table significantly
    UnpivotedColumns = Table.UnpivotOtherColumns(TableBeforeUnpivot, {"ColumnNameOrig"}, "Attribute", "Value"),

    FilteredForFocalValue = Table.SelectRows(UnpivotedColumns, each [Value] = valueToFind),

    // These are two main outputs from this section
    FoundColName = FilteredForFocalValue{0}[ColumnNameOrig],
    FoundColNum = List.PositionOf(ChangeFieldNameToColNameOrig[ColumnNameOrig], FoundColName),
    
    #"---Find row with value in found column ---" = "Find the row number of the value within the target column",
    startTableForRowFind = BaseTableForFinds,
    
    KeptFocalCols = Table.SelectColumns(startTableForRowFind,{"ExcelRowNums", FoundColName}),

    FilteredFocalCallForFocalValue = Table.SelectRows(KeptFocalCols, 
        each (Record.Field(_, FoundColName) = valueToFind)
        ),

    // Final output from this section
    FoundRowNum = FilteredFocalCallForFocalValue{0}[ExcelRowNums],

    #"---Return final cell address ---" = "Return the final cell address as {RowNum, ColNum}",
    RowNumExcel = FoundRowNum, 
    RowNumExcelRel = Text.From(FoundRowNum), // for relative address
    RowNumExcelAbs = "$" & Text.From(RowNumExcel), // for absolute address
    ColNumExcel = FoundColNum, // Already correct; don't need to adjust for the ExcelRowNums column
    ColLetter = Text.From(Character.FromNumber(65 + ColNumExcel - 1)), // A=65 in ASCII
    ColLetterAbs = "$" & ColLetter,
    ResultRecord = [
        Value = valueToFind,
        RowNum = RowNumExcel,
        ColNum = ColNumExcel,
        ColLetter = ColLetter,
        AddressRel = ColLetter & RowNumExcelRel,
        AddressColAbs = ColLetterAbs & RowNumExcelRel,
        AddressRowAbs = ColLetter & RowNumExcelAbs,
        AddressAbs = ColLetterAbs & RowNumExcelAbs,
        aryRowCol = {RowNumExcel, ColNumExcel}
    ]
in
    ResultRecord
