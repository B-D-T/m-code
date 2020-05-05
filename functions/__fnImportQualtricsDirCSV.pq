let
    Source = Folder.Files("C:\Users\dtyler\OneDrive - Western Carolina University\Research\Rivalry\Data\OmniData\LeagueDataCSV_20191013"),
    IgnoreHiddenFiles = Table.SelectRows(Source, each [Attributes]?[Hidden]? <> true),

    AddColWithDataFromEachCSV = Table.AddColumn(IgnoreHiddenFiles, "TransformFile", each Csv.Document([Content],[Delimiter=",", Encoding=1252, QuoteStyle=QuoteStyle.None]), Table.Type),
    
    RenamedNameCol = Table.RenameColumns(AddColWithDataFromEachCSV, {"Name", "SourceFileName"}),
    KeepOnlyFilenameAndData = Table.SelectColumns(RenamedNameCol, {"SourceFileName", "TransformFile"}),
    
    // Each file has a different number of columns, but they all come in as Column1, Column2, etc. We find the one with the most columns, then use that as our sample file.
    AddedCol_NumOfCols = Table.AddColumn(KeepOnlyFilenameAndData, "NumOfCols", each List.Count(Table.ColumnNames([TransformFile])), type number),
    AddedRowIndex = Table.AddIndexColumn(AddedCol_NumOfCols, "Index", 0, 1),
    numIndexForSampleFile = Table.SelectRows(AddedRowIndex, each [NumOfCols] = List.Max(AddedRowIndex[NumOfCols]))[Index]{0},

    AddedFieldsFromFiles = Table.ExpandTableColumn(KeepOnlyFilenameAndData, "TransformFile", Table.ColumnNames(KeepOnlyFilenameAndData[TransformFile]{numIndexForSampleFile}))
in
    AddedFieldsFromFiles



// fQulatricsHdrMap from Student data file
(qualtricsCSVOutputTable as table) as table =>
let
    Source = qualtricsCSVOutputTable,
    QualtricsHdrRows = Table.FirstN(Source,3),
    DemotedColumnNumsToRow = Table.DemoteHeaders(QualtricsHdrRows),
    TransposedTable = Table.Transpose(DemotedColumnNumsToRow),
    RenamedHeaderCols = Table.RenameColumns(TransposedTable,{{"Column1", "ColumnNum"}, {"Column2", "QuesCode"}, {"Column3", "QuesLabel"}, {"Column4", "QuesCodeJSON"}}),
    AddedQuesCodeClean = Table.AddColumn(RenamedHeaderCols, "QuesCodeClean", each Text.BetweenDelimiters([QuesCodeJSON], """:""", """"), type text),

    //Create the header that will be used in the calculations
    AddedHdrForPQ = Table.AddColumn(AddedQuesCodeClean, "HdrForPQ", each if Text.Start([QuesCodeClean],3) = "QID" then [QuesLabel] else [QuesCodeClean], type text),
    RemoveLeadingUnderscore = Table.TransformColumns(AddedHdrForPQ, {{"HdrForPQ", each if Text.StartsWith(_, "_") then Text.AfterDelimiter(_, "_") else _, type text}}),
    RemoveScoreColSpecifics = Table.TransformColumns(RemoveLeadingUnderscore, {{"HdrForPQ", each if Text.StartsWith(_, "SC_") then "ScoreCol" else _, type text}}),

    SetDataTypes = Table.TransformColumnTypes(RemoveScoreColSpecifics, { {"ColumnNum", type text}, {"QuesCode", type text}, {"QuesLabel", type text}, {"QuesCodeJSON", type text}})
in
    SetDataTypes




// ApprenticeshipInfo > qselQtrxOptionEntries
// First 3ish steps are useful.
    let
    Source = Excel.CurrentWorkbook(){[Name="tblStuPrefNum"]}[Content],

    FieldHeadings = Table.Transpose(Table.FirstN(Source,2)),
    RenamedFieldCols = Table.RenameColumns(FieldHeadings,{{"Column1", "QtrxCode"}, {"Column2", "QtrxLabel"}}),
    FilteredForPreferencePoints = Table.SelectRows(RenamedFieldCols, each Text.StartsWith([QtrxCode], "PrefPts_")),
    RemovedExtraTextInOptionName = Table.ReplaceValue(FilteredForPreferencePoints,"PointAllocations - ","",Replacer.ReplaceText,{"QtrxLabel"}),
    AddedQtrxEntryCode = Table.AddColumn(RemovedExtraTextInOptionName, "QtrxEntryCode", each Number.From(Text.AfterDelimiter([QtrxCode], "_")) , Int64.Type),
    SetDataTypes = Table.TransformColumnTypes(AddedQtrxEntryCode,{{"QtrxCode", Text.Type}}),
    CurrentApprOptionsTable = Table.SelectRows(qtblApprOptions, each [Term] = "Spring 2020"),
    MergedWithApprOptions = Table.NestedJoin(SetDataTypes, {"QtrxLabel"}, CurrentApprOptionsTable, {"Department"}, "qtblApprOptions", JoinKind.LeftOuter),
    AddedOptionIDs = Table.ExpandTableColumn(MergedWithApprOptions, "qtblApprOptions", {"OptionID", "ApprOptionID"}, {"OptionID", "ApprOptionID"})
in
    AddedOptionIDs

// ApprenticeshipInfo > qselStuPrefQualtrics
// Start & middle MIGHT be useful.
let

    Source = Excel.CurrentWorkbook(){[Name="tblStuPrefNum"]}[Content],
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),

    listStaticCols = {"StuNameFLUserEntered", "StuIDUserEntered", "AddlComments"},
    RenamedStaticStuPrefCols = Table.RenameColumns(PromotedHeaders,{ {"Q2", "StuNameFLUserEntered"}, {"Q3", "StuIDUserEntered"}, {"Q4", "AddlComments"} } ),

    listOptionCols = qselQtrxOptionEntries[QtrxCode],
    listColsToKeep = listStaticCols & listOptionCols,
    StuPrefQualtricsLimited = Table.Skip( Table.SelectColumns(RenamedStaticStuPrefCols, listColsToKeep), 2),

    NewNamesForOptionCols = Table.SelectColumns(qselQtrxOptionEntries, {"QtrxCode", "OptionID"} ),
    RemovedNullOptionIDs = Table.SelectRows(NewNamesForOptionCols, each ([OptionID] <> null)),
    listRenameZipper = Table.AddColumn(RemovedNullOptionIDs, "RenameZipper", each {[QtrxCode], "PointsOpt" & Text.From([OptionID]) })[RenameZipper],
    RenamedOptionCols = Table.RenameColumns(StuPrefQualtricsLimited, listRenameZipper, null),

    MergedWithRoster = Table.NestedJoin(RenamedOptionCols, {"StuIDUserEntered"}, tblCourseRoster, {"StudentID"}, "tblCourseRoster", JoinKind.LeftOuter),
    AddedStuRosterInfo = Table.ExpandTableColumn(MergedWithRoster, "tblCourseRoster", {"StudentID", "StudentNameLF", "StudentNameFL", "CumulGPA", "EarnedHours"}, {"StudentID", "StudentNameLF", "StudentNameFL", "CumulGPA", "EarnedHours"}),
    AddedGPAandHrs = Table.AddColumn(AddedStuRosterInfo, "GPAandHrs", each Number.ToText([CumulGPA],"f1") & " (" & Number.ToText([EarnedHours], "d") & ")", type text)
in
    AddedGPAandHrs