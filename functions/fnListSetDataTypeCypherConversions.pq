// LibPQ("fnListSetDataTypeCypherConversions")
// As part of error checking, look at the input list of Cypher conversion statements.
// If any of the items are NOT valid Cypher conversions or are null, use toString instead.
// [Optional] Also add toString as many times as necessary such that the length of the conversion statement list equals the inputTotalLength argument 

(inputConversionStatements as list, optional inputTotalLength as number) =>
let
    //inputConversionStatements = {"date", "toFloat"}, inputTotalLength = 5, // testing
    tblDataTypesM = LibPQ("tblDataTypesM"),

    // Create unique list of Cypher conversion entries (toString, toFloat, date, toInteger, etc.) 
    listCypherConversionOptions = List.RemoveNulls( List.Distinct( tblDataTypesM[CypherConversion] ) ),

    // Find all the user-entered types that are NOT in the actual list of Cypher conversion statements
    listItemsToChange = List.Distinct( List.Difference(inputConversionStatements, listCypherConversionOptions) ),

    // Create list of "toString" entries that is the same length as the list of values that need to change
    listChangeTo = List.Repeat( {"toString"} , List.Count(listItemsToChange) ),

    // Replace everything that isn't a Cypher conversion statement with "toString"
    listChangeToValues = List.ReplaceRange(listItemsToChange, 0, List.Count(listItemsToChange) , listChangeTo),

    // Create a list of lists where each item in the outer list has two rows: value to change, value to use instead
    listChangeZipper = List.Zip ( {listItemsToChange, listChangeToValues} ),
    listDataTypeRowInitialCleaned = List.ReplaceMatchingItems(inputConversionStatements, listChangeZipper ),

    // If the number of conversion statements we SHOULD have (inputTotalLength) is larger than the number of conversion statements provided,
    // fill in toString for any columns without CypherConversion statements
    numTotalDesiredConversionStatements = inputTotalLength,
    numConversionStatements = List.Count(listDataTypeRowInitialCleaned),
    listConversionStatements = listDataTypeRowInitialCleaned & List.Repeat( {"toString"} , numTotalDesiredConversionStatements-numConversionStatements )
in
    listConversionStatements