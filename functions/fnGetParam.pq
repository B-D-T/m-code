// fnGetParam.pq

// This is a glorified XLOOKUP.
// It returns the value for a given key from within an Excel-based parameter definition table.
// Converts the result to a specified datatype.
// Also supports returning a list of values when the parameter value is comma-delimited (use blnReturnList = true).
//
// Quick Use (copy/paste):
// - Default source (Excel.CurrentWorkbook), default table/columns:
//   fnGetParam("CourseCRNs")
// - Return list of numbers:
//   fnGetParam("CourseCRNs", "number", true)
// - Custom table + custom key/value columns:
//   fnGetParam("CourseCRNs", "number", true, "ArgumentsTable", "Lookup Values", "Values to return")
// - Direct table source (bypasses Name/Content workbook lookup):
//   fnGetParam("CourseCRNs", "number", true, null, null, null, tblParamSource)
// - CSV path source:
//   fnGetParam("CourseCRNs", "number", true, null, null, null, "C:\\Data\\parameters.csv")
//
// Failure Decoder (error reason -> likely fix):
// - ⚠️ InvalidParameters: one or more arguments are blank/invalid; check key, datatype, and column/table names.
// - ⚠️ MissingParameterTable: source resolved, but named table was not found; check source and strParameterTableName.
// - ⚠️ MissingColumns: source table does not have required key/value columns; check strKeyFieldName/strValueFieldName.
// - ⚠️ MultipleMatches: lookup key matched multiple rows; make keys unique in parameter source.
// - ⚠️ ConversionFailed: found value could not be converted to requested datatype; fix source value or datatype arg.

//
// Note for Windows file paths:
//   If you hardcode a path in M code, use double backslashes (e.g., "C:\\Data\\parameters.csv")
//   or single forward slashes (e.g., "C:/Data/parameters.csv") to avoid escape-sequence issues.
//   If the path comes from user input or a parameter, escaping is not needed—only in string literals in code.

let

// ===========================================================================================
// SECTION 1 — PUBLIC API
// ===========================================================================================

// Main orchestration function.
// Workflow:
// 1) Normalize and validate user inputs.
// 2) Resolve the parameter source into a concrete table and validate required columns.
// 3) Lookup value by key.
// 4) Return a scalar typed value or a typed list.
fnMainFunc =
    (
        strKeyName as text,
        optional strDataType as text,
        optional blnReturnList as logical,
        optional strParameterTableName as text,
        optional strKeyFieldName as text,
        optional strValueFieldName as text,
        optional varParamSource as any
    ) as any =>

    let

        // // Values for testing
        // strKeyName = "filenameTeamInfo", strDataType = "text", blnReturnList = false, strParameterTableName = "tblParameters", strKeyFieldName = "ParameterKey", strValueFieldName = "ParameterValue", varParamSource = null

        // `prm` is the single canonical configuration object used by downstream helpers.
        initialParamsRecord = fnBuildParams(strKeyName, strDataType, blnReturnList, strParameterTableName, strKeyFieldName, strValueFieldName, varParamSource),
        prm = fnValidateParams(initialParamsRecord),

        // Look up the key in the parameter table
        sourceParamTable = fnResolveParamTable(prm),
        rawFoundValue = fnGetRawValue(sourceParamTable, prm),

        // Scalar and list outputs share the same raw lookup result; only final shaping differs.
        result =
            if prm[ReturnList] = true
            then fnToList(rawFoundValue, prm[DataType])
            else fConvertData(rawFoundValue, prm[DataType])
    in
        result,

// ===========================================================================================
// SECTION 2 — CONFIGURATION
// ===========================================================================================

// Data-type alias groups used for validation and conversion.
// Keep proper-cased values here for documentation/UX; use `lstAllowedDataTypesNormalized` for case-insensitive checks.
// Why this exists: centralizing aliases in one place prevents validation and conversion rules from drifting apart.
lstDataTypesNumber = {"number", "toFloat", "toInteger"},
lstDataTypesDate = {"date"},
lstDataTypesDateTime = {"datetime"},
lstDataTypesLogical = {"logical", "toBoolean"},
lstAllowedDataTypes = List.Combine({{"text"}, lstDataTypesNumber, lstDataTypesDate, lstDataTypesDateTime, lstDataTypesLogical}),
lstAllowedDataTypesNormalized = List.Transform(lstAllowedDataTypes, each Text.Lower(_)),

// ===========================================================================================
// SECTION 3 — INPUT HANDLING
// ===========================================================================================

// Small utility used across builders/parsers to implement optional defaults.
// Equivalent to a nullable coalesce for this codebase.
// Why this exists: default assignment happens in multiple places; this keeps null/default behavior consistent.
fnInputOrDefault = (value as nullable any, defaultValue as any) as any =>
    if value <> null then value else defaultValue,

// Normalizes raw function inputs into a single parameter record
// Why this exists: this creates one canonical config object so helper signatures stay simple as features grow.
fnBuildParams = (
    keyName as text,
    optional dataType as nullable text,
    optional returnList as nullable logical,
    optional parameterTableName as nullable text,
    optional keyFieldName as nullable text,
    optional valueFieldName as nullable text,
    optional paramSource as nullable any
    ) as record =>
    [
        KeyName = keyName,
        DataType = if dataType <> null then Text.Lower(dataType) else "text",
        ReturnList = fnInputOrDefault(returnList, false),
        ParameterTableName = fnInputOrDefault(parameterTableName, "tblParameters"),
        KeyFieldName = fnInputOrDefault(keyFieldName, "ParameterKey"),
        ValueFieldName = fnInputOrDefault(valueFieldName, "ParameterValue"),
        ParamSource = paramSource
    ],

// Validates the normalized parameter record and throws structured errors for bad inputs.
// This is the single gate for input sanity so downstream functions can assume a stable parameter contract.
// Why this exists: fail-fast validation keeps low-level helpers focused on lookup/conversion instead of rechecking args.
fnValidateParams = (prm as record) as record =>
    let
        keyName = Text.Trim(prm[KeyName]),
        dataType = Text.Trim(prm[DataType]),
        parameterTableName = Text.Trim(prm[ParameterTableName]),
        keyFieldName = Text.Trim(prm[KeyFieldName]),
        valueFieldName = Text.Trim(prm[ValueFieldName]),

        // Check for invalid parameters and accumulate error info
        invalidDataType = List.Contains(lstAllowedDataTypesNormalized, dataType) = false,

        // Create a list of invalid parameters for error reporting
        invalidParams = List.RemoveNulls({
            if keyName = "" then "strKeyName" else null,
            if parameterTableName = "" then "strParameterTableName" else null,
            if keyFieldName = "" then "strKeyFieldName" else null,
            if valueFieldName = "" then "strValueFieldName" else null,
            if invalidDataType then "strDataType" else null
        }),

        // Construct a cleaned and validated parameter record for downstream use
        validatedPrm = [
            KeyName = keyName,
            DataType = dataType,
            ReturnList = prm[ReturnList],
            ParameterTableName = parameterTableName,
            KeyFieldName = keyFieldName,
            ValueFieldName = valueFieldName,
            ParamSource = prm[ParamSource]
        ],

        validatedRecord = if List.IsEmpty(invalidParams)
            then validatedPrm
            else error Error.Record(
                "⚠️ InvalidParameters",
                "➡️ One or more function parameters are invalid.",
                [
                    InvalidParameterNames = invalidParams,
                    AllowedDataTypeValues = lstAllowedDataTypes,
                    ResolvedParameterRecord = validatedPrm
                ])
    in
        validatedRecord,

// ===========================================================================================
// SECTION 4 — SOURCE RESOLUTION
// ===========================================================================================

// --- Diagnostics (used by source resolution for dispatch and error context) ----------------

// Returns a lowercase file extension without the leading dot; returns empty text when unavailable
// Why this exists: extension parsing is reused in source dispatch and should remain deterministic.
fnGetFileExtension = (path as text) as text =>
    let
        trimmed = Text.Trim(path),
        extWithDot = if Text.Contains(trimmed, ".") then Text.AfterDelimiter(trimmed, ".", {0, RelativePosition.FromEnd}) else ""
    in
        Text.Lower(extWithDot),

// Returns a compact source-kind label used by dispatch and diagnostics.
// Why this exists: dispatch logic and error telemetry both need the same source-kind vocabulary.
fnSourceKind = (value as any) as text =>
    if Value.Is(value, type null) then "null" else
    if Value.Is(value, type function) then "function" else
    if Value.Is(value, type text) then "text" else
    if Value.Is(value, type table) then "table" else
    if Value.Is(value, type binary) then "binary" else
    "other",

// Returns a short preview of the source value for diagnostics
// Why this exists: when source resolution fails, a compact preview is often enough to spot bad inputs quickly.
fnSourcePreview = (value as any) as text =>
    if Value.Is(value, type null) then "null" else
    if Value.Is(value, type text) then
        let t = Text.Trim(value)
        in if Text.Length(t) > 180 then Text.Start(t, 180) & "..." else t
    else if Value.Is(value, type table) then
        let
            cols = Table.ColumnNames(value),
            rows = Table.RowCount(Table.FirstN(value, 2000))
        in
            "table(cols=" & Text.From(List.Count(cols)) & ", rows(first<=2000)=" & Text.From(rows) & ")"
    else if Value.Is(value, type binary) then "binary" else
    if Value.Is(value, type function) then "function" else
    "other",

// --- Source handlers -----------------------------------------------------------------------

// Converts Json.Document output into a tabular form.
// Supported JSON roots: table, list, record, scalar.
// Scalars/lists of scalars become a single `Value` column table.
// Why this exists: callers only know how to work with tables; JSON needs to be normalized to that contract.
fnJsonValueToTable = (jsonValue as any) as table =>
    if Value.Is(jsonValue, type table) then jsonValue else
    if Value.Is(jsonValue, type list) then
        let
            asList = jsonValue,
            listCount = List.Count(asList),
            firstValue = if listCount > 0 then asList{0} else null
        in
            if listCount = 0 then #table(type table [Value = any], {})
            else if Value.Is(firstValue, type record) then Table.FromRecords(asList)
            else Table.FromList(asList, Splitter.SplitByNothing(), {"Value"})
    else if Value.Is(jsonValue, type record) then Table.FromRecords({jsonValue})
    else #table(type table [Value = any], {{jsonValue}}),

// Loads a CSV binary and promotes the first row as headers when possible
// Why this exists: CSV is a common source and this keeps header-promotion policy consistent across call paths.
fnCsvBinaryToTable = (csvBinary as binary) as table =>
    let
        rawCsv = Csv.Document(csvBinary, [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
        promotedTry = try Table.PromoteHeaders(rawCsv, [PromoteAllScalars = true])
    in
        if promotedTry[HasError] then rawCsv else promotedTry[Value],

// Loads an Excel workbook binary and shapes it like Excel.CurrentWorkbook (Name, Content)
// Why this exists: workbook-based sources are normalized to a shared catalog shape before table extraction.
fnWorkbookBinaryToCatalog = (wbBinary as binary) as table =>
    let
        wb = Excel.Workbook(wbBinary, null, true),
        selected = Table.SelectColumns(wb, {"Name", "Data"}),
        renamed = Table.RenameColumns(selected, {{"Data", "Content"}})
    in
        renamed,

// Loads a workbook table catalog from a file path
// Why this exists: separates file I/O from workbook parsing so each concern can be debugged independently.
fnWorkbookPathToCatalog = (path as text) as table => fnWorkbookBinaryToCatalog(File.Contents(path)),

// Retrieves the named parameter table from a workbook catalog (Name, Content)
// Why this exists: isolates the legacy Name/Content lookup pattern to one boundary adapter.
fnGetParamTableFromWorkbookCatalog = (prm as record, workbookCatalog as table) as table =>
    let
        sourceTry = try workbookCatalog{[Name=prm[ParameterTableName]]}[Content]
    in
        if sourceTry[HasError]
        then error fnErrMissingParameterTable(prm, sourceTry[Error], [WorkbookCatalogColumns = Table.ColumnNames(workbookCatalog), WorkbookCatalogRowCount = Table.RowCount(Table.FirstN(workbookCatalog, 2000))])
        else sourceTry[Value],

// Resolves configured source into a single parameter table.
// Dispatch strategy:
// - table: treat as direct table, or workbook catalog if it has Name/Content columns.
// - text: treat as file path and dispatch by extension.
// - binary: attempt Excel workbook, then CSV, then JSON.
// - function: evaluated earlier to produce one of the above input kinds.
// Why this exists: all source-type complexity is quarantined here so lookup/conversion logic stays source-agnostic.
fnGetParamTableFromSource = (prm as record) as table =>
    let
        sourceInput = prm[ParamSource],
        sourceInputKind = fnSourceKind(sourceInput),
        resolvedInput =
            if sourceInput = null
            then Excel.CurrentWorkbook()
            else if Value.Is(sourceInput, type function)
            then
                let callTry = try sourceInput()
                in if callTry[HasError] then error fnErrMissingParameterTable(prm, callTry[Error], [OriginalSourceKind = sourceInputKind, SourceInvocation = "function()", OriginalSourcePreview = fnSourcePreview(sourceInput)]) else callTry[Value]
            else sourceInput,
        resolvedInputKind = fnSourceKind(resolvedInput),

        fnFromTable = (tbl as table) as table =>
            let
                colNames = Table.ColumnNames(tbl),
                isWorkbookCatalogShape = List.Contains(colNames, "Name") and List.Contains(colNames, "Content")
            in
                if isWorkbookCatalogShape
                then fnGetParamTableFromWorkbookCatalog(prm, tbl)
                else tbl,

        fnFromText = (txt as text) as table =>
            let
                srcPath = Text.Trim(txt),
                ext = fnGetFileExtension(srcPath),
                textHandlers = [
                    xlsx = () => fnGetParamTableFromWorkbookCatalog(prm, fnWorkbookPathToCatalog(srcPath)),
                    xlsm = () => fnGetParamTableFromWorkbookCatalog(prm, fnWorkbookPathToCatalog(srcPath)),
                    xlsb = () => fnGetParamTableFromWorkbookCatalog(prm, fnWorkbookPathToCatalog(srcPath)),
                    xls = () => fnGetParamTableFromWorkbookCatalog(prm, fnWorkbookPathToCatalog(srcPath)),
                    csv = () => fnCsvBinaryToTable(File.Contents(srcPath)),
                    json = () => fnJsonValueToTable(Json.Document(File.Contents(srcPath)))
                ],
                selectedTextHandler = Record.FieldOrDefault(textHandlers, ext, null)
            in
                if selectedTextHandler <> null
                then selectedTextHandler()
                else error fnErrUnsupportedParamSource(prm, "text(" & ext & ")", [OriginalSourceKind = sourceInputKind, ResolvedSourceKind = resolvedInputKind, PathProvided = srcPath, FileExtension = ext, OriginalSourcePreview = fnSourcePreview(sourceInput)]),

        fnFromBinary = (bin as binary) as table =>
            let
                wbTry = try fnGetParamTableFromWorkbookCatalog(prm, fnWorkbookBinaryToCatalog(bin)),
                csvTry = if wbTry[HasError] then try fnCsvBinaryToTable(bin) else wbTry,
                jsonTry = if csvTry[HasError] then try fnJsonValueToTable(Json.Document(bin)) else csvTry
            in
                if jsonTry[HasError]
                then error fnErrUnsupportedParamSource(prm, "binary", [OriginalSourceKind = sourceInputKind, ResolvedSourceKind = resolvedInputKind, TriedParsers = {"Excel.Workbook", "Csv.Document", "Json.Document"}, OriginalSourcePreview = fnSourcePreview(sourceInput)])
                else jsonTry[Value],

        // Switch-like dispatch map for resolved source kind.
        sourceKindHandlers = [
            table = fnFromTable,
            text = fnFromText,
            binary = fnFromBinary
        ],
        selectedSourceHandler = Record.FieldOrDefault(sourceKindHandlers, resolvedInputKind, null),
        paramTable =
            if selectedSourceHandler <> null
            then selectedSourceHandler(resolvedInput)
            else error fnErrUnsupportedParamSource(prm, resolvedInputKind, [OriginalSourceKind = sourceInputKind, ResolvedSourceKind = resolvedInputKind, OriginalSourcePreview = fnSourcePreview(sourceInput)])
    in
        paramTable,

// ===========================================================================================
// SECTION 5 — LOOKUP & CONVERSION
// ===========================================================================================

// Resolves source once and validates required headers once.
// Downstream lookup can safely assume key/value columns exist.
// Why this exists: validates table shape once up front to avoid repeated checks and branch noise in hot paths.
// Contract established here:
// - Returned table always contains prm[KeyFieldName] and prm[ValueFieldName].
// - No downstream helper should re-check source type or required headers.
// - Name/Content workbook-catalog handling stays contained in source-resolution helpers.
fnResolveParamTable = (prm as record) as table =>
    let
        paramTable = fnGetParamTableFromSource(prm),
        sourceColumns = Table.ColumnNames(paramTable),
        missingColumns = List.Difference({prm[KeyFieldName], prm[ValueFieldName]}, sourceColumns)
    in
        if List.IsEmpty(missingColumns)
        then paramTable
        else error fnErrMissingColumns(prm, sourceColumns, missingColumns),

// Performs key lookup against an already-resolved and header-validated table.
// Return contract:
// - 0 matches => null
// - 1 match => that row's value-field value (as text)
// - >1 matches => structured duplicate-match error
// Why this exists: this function owns only key-matching semantics, not source parsing or schema validation.
// Contract expected from caller:
// - `Source` is already resolved and has required key/value headers (via fnResolveParamTable).
fnGetRawValue = (Source as table, prm as record) as nullable text =>
    let
        fnRowMatchesKey = (row as record) as logical => Record.FieldOrDefault(row, prm[KeyFieldName], null) = prm[KeyName],

        matchedRows = Table.SelectRows(Source, each fnRowMatchesKey(_)),
        numOfMatchedRows = Table.RowCount(matchedRows),
        
        fnValueFromFirstMatch = () => 
            let firstMatchedRow = matchedRows{0}
            in Record.FieldOrDefault(firstMatchedRow, prm[ValueFieldName], null),

        errMultipleMatches = fnErrMultipleMatches(prm, Source, matchedRows),

        result =
            if numOfMatchedRows = 0 then null
            else if numOfMatchedRows > 1 then error errMultipleMatches
            else Text.From(fnValueFromFirstMatch())
    in
        result,

// Splits comma-delimited text into a typed list.
// List element conversion reuses `fConvertData` so scalar/list conversion stay consistent.
// Why this exists: list-mode should behave like repeated scalar conversion, not a separate conversion system.
fnToList = (strValue as nullable text, strDataType as text) as list =>
    if strValue is null then {} else
    let
        ListAsText = List.Transform(Text.Split(strValue, ","), each Text.Trim(_)),
        ConvertListData = List.Transform(ListAsText, each fConvertData(_, strDataType))
    in
        ConvertListData,

// Converts a scalar value using a switch-like dispatch:
// 1) alias -> canonical type
// 2) canonical type -> converter function
// 3) converter(value) with structured conversion error wrapping
// Why this exists: converter dispatch keeps datatype branching maintainable as aliases and target types expand.
fConvertData = (strValue as nullable text, strDataType as text) =>
    if strValue is null then null else
    let
        typeAliasToCanonical = [
            number = "number",
            tofloat = "number",
            tointeger = "number",
            date = "date",
            datetime = "datetime",
            logical = "logical",
            toboolean = "logical",
            text = "text"
        ],
        canonicalType = Record.FieldOrDefault(typeAliasToCanonical, strDataType, "text"),
        typeConverters = [
            number = Number.From,
            date = Date.From,
            datetime = DateTime.From,
            logical = Logical.From,
            text = Text.From
        ],
        selectedConverter = Record.Field(typeConverters, canonicalType),
        conversionTry =
            try selectedConverter(strValue)
    in
        if conversionTry[HasError]
        then error Error.Record(
            "⚠️ ConversionFailed",
            "➡️ Could not convert parameter value to the requested data type.",
            [
                ParameterValue = strValue,
                RequestedDataType = strDataType,
                InnerErrorRecord = conversionTry[Error]
            ])
        else conversionTry[Value],

// ===========================================================================================
// SECTION 6 — ERROR BUILDERS
// ===========================================================================================

// Builds a rich error record when a named parameter table cannot be loaded from the chosen source.
// Why this exists: all source-load failures funnel through one shape, making diagnostics predictable and grep-friendly.
fnErrMissingParameterTable = (prm as record, innerError as any, optional sourceContext as nullable record) as record =>
    let
        contextRecord = if sourceContext = null then [SourceContext = null] else sourceContext
    in
    Error.Record(
        "⚠️ MissingParameterTable",
        "➡️ Could not load the parameter table from the configured source.",
        Record.Combine({
            [
                FunctionNameWithError = "fnGetParam",
                ParameterTableName = prm[ParameterTableName],
                InnerErrorRecord = innerError
            ],
            contextRecord
        })),

// Builds a rich error record when source resolution cannot produce a usable table.
// Why this exists: source resolution can fail for many reasons; this normalizes those failures into one actionable error.
fnErrUnsupportedParamSource = (prm as record, sourceType as text, optional diagnostics as nullable record) as record =>
    let
        diagRecord = if diagnostics = null then [Diagnostics = null] else diagnostics
    in
    Error.Record(
        "⚠️ UnsupportedParamSource",
        "➡️ The provided parameter source could not be resolved to a table.",
        Record.Combine({
            [
                FunctionNameWithError = "fnGetParam",
                ResolvedSourceType = sourceType,
                ParameterTableName = prm[ParameterTableName],
                Hint = "Use null (default), a path string (.xlsx/.csv/.json), a table, a binary, or a function returning one of those."
            ],
            diagRecord
        })),

// Builds a rich Error.Record for duplicate-key matches
// Why this exists: duplicate keys indicate ambiguous configuration and should surface as a clear, contextual error.
fnErrMultipleMatches = (prm as record, source as table, matchedRows as table) as record =>
    let
        numOfMatchedRows = Table.RowCount(matchedRows),
        totalRowsInTable = Table.RowCount(source)
    in
        Error.Record(
            "⚠️ MultipleMatches",
            "➡️ More than one row matched the requested key. Ensure parameter keys are unique.",
            [
                FunctionNameWithError = "fnGetParam",
                ParameterTableName = prm[ParameterTableName],
                ColumnNameWithKeys = prm[KeyFieldName],
                LookupKey = prm[KeyName],
                ColumnNameWithValues = prm[ValueFieldName],
                NumberOfMatches = numOfMatchedRows,
                TotalRowsInTable = totalRowsInTable
            ]),

// Builds a rich Error.Record when required key/value columns are missing from the resolved table
// Why this exists: header validation errors are common when schema drifts, so this centralizes the schema message.
fnErrMissingColumns = (prm as record, sourceColumns as list, missingColumns as list) as record =>
    Error.Record(
        "⚠️ MissingColumns",
        "➡️ One or more required columns were not found in the parameter table.",
        [
            FunctionNameWithError = "fnGetParam",
            ParameterTableName = prm[ParameterTableName],
            RequiredColumnNames = {prm[KeyFieldName], prm[ValueFieldName]},
            MissingColumnNames = missingColumns,
            AvailableColumnNames = sourceColumns
        ]),

// ===========================================================================================
// SECTION 7 — METADATA
// ===========================================================================================

// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------
#"Below this line is metadata and type annotation; There is no further function logic." = Text.Repeat("-", 50),
// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------

fnType = type function
(
    strKeyName as (type text meta
        [
            Documentation.FieldCaption = "Key to look up",
            Documentation.FieldDescription = "Parameter key to find in the key column.",
            Documentation.SampleValues = {"CourseCRNs", "filename", "current user"}
        ]),
    optional strDataType as (type text meta
        [
            Documentation.FieldCaption = "Convert result to",
            Documentation.FieldDescription = "Data type to which we'll convert the returned value(s)",
            Documentation.DefaultValue = "text",
            Documentation.AllowedValues = {"text", "number", "date", "datetime", "logical", "toFloat", "toInteger", "toBoolean"},
            Documentation.SampleValues = {"text", "number", "toBoolean"}
        ]),
    optional blnReturnList as (type logical meta
        [
            Documentation.FieldCaption = "Return as list",
            Documentation.FieldDescription = "When true, this splits comma-delimited values and returns the values as list;
            each value in the list is also converted to the type specified by strDataType.",
            Documentation.DefaultValue = false,
            Documentation.AllowedValues = {true, false}
        ]),
    optional strParameterTableName as (type text meta
        [
            Documentation.FieldCaption = "Parameter table",
            Documentation.FieldDescription = "Excel table name in the current workbook that stores parameters.",
            Documentation.DefaultValue = "tblParameters",
            Documentation.SampleValues = {"tblParameters"}
        ]),
    optional strKeyFieldName as (type text meta
        [
            Documentation.FieldCaption = "Key column",
            Documentation.FieldDescription = "Column name that contains parameter keys (i.e., the lookup values).",
            Documentation.DefaultValue = "ParameterKey",
            Documentation.SampleValues = {"ParameterKey"}
        ]),
    optional strValueFieldName as (type text meta
        [
            Documentation.FieldCaption = "Value column",
            Documentation.FieldDescription = "Column name that contains parameter values (i.e., the values to return).",
            Documentation.DefaultValue = "ParameterValue",
            Documentation.SampleValues = {"ParameterValue"}
        ]),
    optional varParamSource as (type any meta
        [
            Documentation.FieldCaption = "Parameter source",
            Documentation.FieldDescription = "Source for parameter data. Supports null (default Excel.CurrentWorkbook), function, table, binary, or path string (.xlsx/.csv/.json).",
            Documentation.DefaultValue = "Excel.CurrentWorkbook"
        ])
) as any meta
    [
        Documentation.Name = "fnGetParam",
        Documentation.Author = "B. David Tyler",
        Documentation.Version = "2026.04.29",
        Documentation.Description = "Looks up a key in a parameter table and returns the matching value.",
        Documentation.LongDescription = "Searches a table -- or gets a table from an Excel.CurrentWorkbook-like source -- 
        for a row where the key column matches the provided key name and returns the matching value with optional type conversion. 
        Use blnReturnList = true to split comma-delimited values into a typed list; 
        otherwise a single value is returned.
        If no match is found, the function returns null (or {} for list output).
        If multiple matches are found, the function throws an error to prevent ambiguous keys.",
        Documentation.Examples = 
            {
                [
                    Description = "Most common call: Use defaults and return text.",
                    Code = "fnGetParam(""CourseCRNs"")",
                    Result = """80140"", ""80224"""
                ],
                [
                    Description = "Return comma-delimited values as a list of numbers.",
                    Code = "fnGetParam(""CourseCRNs"", ""number"", true)",
                    Result = "{80140, 80224}"
                ],
                [
                    Description = "Use Cypher-compatible type alias for boolean conversion.",
                    Code = "fnGetParam(""EnableSurvey"", ""toBoolean"")",
                    Result = "true"
                ],
                [
                    Description = "Use custom table and column names.",
                    Code = "fnGetParam(""CourseCRNs"", ""number"", true, ""ArgumentsTable"", ""Lookup Values"", ""Values to return"")",
                    Result = "{80140, 80224}"
                ],
                [
                    Description = "Use a direct table as the parameter source (bypasses workbook/table-name lookup).",
                    Code = "fnGetParam(""CourseCRNs"", ""number"", true, null, null, null, tblParamSource)",
                    Result = "{80140, 80224}"
                ],
                [
                    Description = "Use a CSV file path as the parameter source (expects key/value columns in the CSV).",
                    Code = "fnGetParam(""CourseCRNs"", ""number"", true, null, null, null, ""C:/Data/parameters.csv"")",
                    Result = "{80140, 80224}"
                ]
            }
    ]

in
    Value.ReplaceType( 
        fnMainFunc, fnType
        )
