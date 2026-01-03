// fnReadColType

// Reads a column (as a list) and determines its data type based on the values in the column
// Parameters:
// "focalCol" = the input column as a list
// "sampleN" = optional number of rows to sample for type detection (default is 100)

(focalCol as list, optional sampleN as nullable number) as type =>
    let 
        // focalCol = {1, 2, null, 3} // sample for testing
        // sampleN = 100,
        nRows = if sampleN = null then 100 else sampleN,
        lstTypesEachValue = List.Transform(
            List.FirstN(List.RemoveNulls(focalCol), nRows),
            each if _ <> null then Value.Type(_) else null
        ),
        lstTypesInCol = List.Distinct(lstTypesEachValue),
        colType = if List.IsEmpty(lstTypesEachValue) then Any.Type 
            else if List.Count(lstTypesInCol)=1 then lstTypesInCol{0}
            else Any.Type
    in 
        colType
