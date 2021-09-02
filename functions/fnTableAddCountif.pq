// fnTableAddCountif
(tblSource as table, paramGroupingCols as any, optional paramNewColName as text) =>
    let
        listGroupingCols = if Type.Is(Value.Type(paramGroupingCols), type list) then paramGroupingCols else Text.Split(paramGroupingCols,"@#$%^&*()"),
        InsertedIndex = Table.AddIndexColumn(tblSource, "Index", 1, 1, Int64.Type),
        GroupedRows = Table.Group(InsertedIndex, listGroupingCols, {{"Values", each _, type table }}),
        Sorted = Table.TransformColumns(GroupedRows,{{"Values", each Table.AddIndexColumn(Table.Sort(_, "Index"),"GroupIndex")}}),
        ExpandValues = Table.ExpandTableColumn(Sorted, "Values", {"Index", "GroupIndex"}, {"Index", "GroupIndex"}),
        SortedRows = Table.Sort(ExpandValues,{{"Index", Order.Ascending}}),
        InsertedCustom = Table.AddColumn(SortedRows, "CountIf", each [GroupIndex] + 1),
        RemovedColumns = Table.RemoveColumns(InsertedCustom,{"Index", "GroupIndex"}),
        ChangeCountifToNum = Table.TransformColumnTypes(RemovedColumns,{{"CountIf", Int64.Type}}),
        AddedMatchingIndex = Table.AddIndexColumn(ChangeCountifToNum, "Index", 1, 1, Int64.Type),
        MergedTables = Table.NestedJoin(InsertedIndex,"Index", AddedMatchingIndex,"Index", "CountifTable",JoinKind.Inner),
        AddedCountifCol = Table.ExpandTableColumn(MergedTables, "CountifTable", {"CountIf"}),
        RemovedDuplicates = Table.Distinct(AddedCountifCol, List.Combine({listGroupingCols,{"CountIf"}})),

        newColName = if paramNewColName = null then "CountIf" else paramNewColName,
        RenameCountIfCol = Table.RenameColumns(RemovedDuplicates, {"CountIf", newColName}),
        CleanUp = Table.RemoveColumns(RenameCountIfCol,{"Index"})
    in
        CleanUp
