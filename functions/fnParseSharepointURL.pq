// fnParseSharepointURL.pq

let 

// Documentation for the main function - this replaces the type information for the function to show type hints in the Power Query Editor
docstring = type function (
    // Metadata for the parameters
    pathInput as (
        type text meta [
            Documentation.FieldCaption = "Full URL path as a text string",
            Documentation.FieldDescription = "Required. The full SharePoint/OneDrive URL to parse.
            This is obtained by navigating to the directory online,
            clicking ""Details"",
            scrolling to the bottom,
            and clicking the ""Copy direct link"" button next to ""Path"".",
            Documentation.SampleValues = {
                "https://contoso-my.sharepoint.com/personal/my_user_name/Documents/MySubdirectory/",
                "https://contoso.sharepoint.com/sites/MyTeam/Shared%20Documents/General/MySubdirectory/",
                "https://contoso.sharepoint.com/sites/MyTeam-MyChannel/Shared%20Documents/MyChannel/MySubdirectory/"
            }, 
            Formatting.IsCode = true
        ]
    ),
    optional returnType as (
        type text meta [
            Documentation.FieldCaption = "Return as table or record",
            Documentation.FieldDescription = "Optional. Specify ""record"" to return a record of Key/Value pairs.
            Otherwise, the default is to return a table of information.",
            Documentation.AllowedValues = {"table", "record"},
            Formatting.IsCode = false
        ]
    )) as any
    // Metadata for the function itself
    meta [
        Documentation.Name = "fnParseSharepointURL",
        Documentation.Description = "Parses a SharePoint or OneDrive URL and returns structured components as a table or record.",
        Documentation.LongDescription = "
        Parses a SharePoint/OneDrive URL and returns either a ""table"" (default) of information
        or ""record"" with just the Key/Value pairs from the table.",
        Documentation.Author = "B. David Tyler",
        Documentation.Version = "0.0.2",
        Documentation.Examples = {
            [
                Description = "Parse a SharePoint directory to a table of components",
                Code = "fnParseSharepointURL(""https://contoso.sharepoint.com/sites/Team/Shared%20Documents/Folder/"")",
                Result = "(a table with parsed components)"
            ],
            [
                Description = "Parse a OneDrive folder URL to a record of components",
                Code = "fnParseSharepointURL(""https://contoso-my.sharepoint.com/personal/user/Documents/Folder/"", ""record"")",
                Result = "(a record with parsed components)"
            ]
        }
    ],

// This table just has notes to myself about working with paths. These don't do anything - they're here for reference.
InfoTableForDeveloper =
    let 
        // Below are sample paths for different Sharepoint/OneDrive locations.
        // For any directory, make sure to include the trailing slash ("/") at the end of the path to indicate it's a folder;
        // otherwise, Power Query will try to interpret it as a file.

        recOnedrive = [
            sampleName = "OneDrive",
            description = "Individual user's OneDrive account",
            pathRoot = "https://umass-my.sharepoint.com/personal/aperson_umass_edu/",
            pathTarget = "https://umass-my.sharepoint.com/personal/aperson_umass_edu/Documents/Teaching/PowerQuery/SourceDataCSVs/",
            notes = "OneDrive is mostly just a frontend for Sharepoint, but one difference is in the URL structure."
        ],
        recSharepointTeamsMain = [
            sampleName = "SharepointTeamsMain",
            description = "Main Sharepoint document library for an MS Teams site",
            pathRoot = "https://umass.sharepoint.com/sites/MyTeam/",
            pathTarget = "https://umass.sharepoint.com/sites/MyTeam/Shared%20Documents/General/DatabaseDocumentation/Ontology/",
            notes = null
        ],
        recSharepointTeamsChannel = [
            sampleName = "SharepointTeamsChannel",
            description = "Sharepoint document library for a (private) channel in an MS Teams site",
            pathRoot = "https://umass.sharepoint.com/sites/MyTeam-MyChannel/",
            pathTarget = "https://umass.sharepoint.com/sites/MyTeam-MyChannel/Shared%20Documents/MyChannel/MySubdiretory/DBSchema/",
            notes = null
        ],
        SamplePaths = Table.FromRecords({recOnedrive, recSharepointTeamsMain, recSharepointTeamsChannel}),
        AddURIParts = Table.AddColumn(SamplePaths, "URIParts", each Uri.Parts([pathTarget])),
        DuplicateURIParts = Table.DuplicateColumn(AddURIParts, "URIParts", "URIPartsCopy"),

        uriPartsToShow = {"Host", "Path", "Query"},
        ExpandedURIParts = Table.ExpandRecordColumn(DuplicateURIParts, "URIPartsCopy", uriPartsToShow),

        colOrder = {"sampleName", "Host", "Path", "description", "notes", "pathRoot", "pathTarget", "URIParts", "Query"},
        ReorderedColumns = Table.ReorderColumns(ExpandedURIParts, colOrder),
        DemoTable = ReorderedColumns
    in
        DemoTable,

#"----MAIN FUNCTION STARTS HERE----" = "Helper functions first, then the main function body",

PATH_DELIMITER = "/",

// Assign as File or Folder based on whether the path ends with a "/" slash
fnGetLikelyContentType = (path as text) as text =>
    if path = null then null
    else if Text.EndsWith(path, PATH_DELIMITER) then "Folder" else "File",
// Determine the storage type based on the URL host (i.e., OneDrive vs. SharepointTeams)
fnGetLocationStorageType = (uriParts as record) as text =>
    // LocationStorageType is "OneDrive", "SharepointTeams", "Other", or null (for now). 
    // I can't determine how to accurately differentiate SharepointMain from SharepointChannel yet.
    // In theory, I could look for "General" as one of the first subdirectories, but that's not ALWAYS going to work.
    let
        partsHost = Text.Lower(uriParts[Host]),
        LocationStorageType = if (partsHost = null) then null 
            else if partsHost = "" then null
            else if Text.EndsWith(partsHost, "-my.sharepoint.com") then "OneDrive"
            else if Text.EndsWith(partsHost, "sharepoint.com") then "SharepointTeams"
            else "Other"
    in
        LocationStorageType,


// Converts HTML encoded text back to normal text (e.g., %20 to space)
fnDecodeText = (textToDecode as text) as text =>
    // Credit for this elegantly simple solution goes to MS community user
    // [v-jingzhang](https://community.fabric.microsoft.com/t5/Desktop/How-to-convert-these-encode-url-to-normal-text/td-p/2388189)
    // via [Imke Feldmann](https://www.thebiccountant.com/2023/08/01/decode-uri-in-power-query-with-custom-uri-unescapedatastring-function)
    let
        parts = Uri.Parts("http://fakedomain?a=" & textToDecode),
        query = parts[Query],
        decoded = query[a]
    in
        decoded,

fnDecodeSegments = (lstSegments as list) as list => List.Transform(lstSegments, each fnDecodeText(_)),

// Get number of path segments from host to root directory based on storage type
fnGetNumSegmentsFromHostToRoot = (storageType as text) as number => if storageType = null then null
    else if storageType = "OneDrive" then 2
    else if storageType = "SharepointTeams" then 2
    else 0, // Unknown; return just the host

// Given the input information, this creates a record for use in the result table
fnMakeRecordForTable = (Key as text, Value as any, DataType as text, Description as text) as record =>
    [Key = Key, Value = Value, DataType = DataType, Description = Description],

fnMakeResultTable = (lstRecords as list) as table =>
    let
        resultTable = Table.FromRecords(lstRecords),
        typedTable = Table.TransformColumnTypes(resultTable,
            {
                {"Key", type text},
                {"DataType", type text},
                {"Description", type text}
            }
        ),
        SetPrimaryKey = Table.AddKey(typedTable, {"Key"}, true)
    in
        SetPrimaryKey,

// MAIN BODY OF FUNCTION: This is what gets invoked when the function is called
fnParseSharepointURL_INIT = (pathInput as text, optional returnType as text) =>
    let
        partsOrig = Uri.Parts(pathInput),

        LocationStorageType = fnGetLocationStorageType(partsOrig), 

        // Create list of path segments, ignoring any leading/trailing slashes
        lstPathSubdirectories = Text.Split(Text.Trim(partsOrig[Path], PATH_DELIMITER), PATH_DELIMITER),

        numSegmentsFromHostToRoot = fnGetNumSegmentsFromHostToRoot(LocationStorageType),
        lstSubdirectoriesHostToRoot = List.FirstN(lstPathSubdirectories, numSegmentsFromHostToRoot),
        lstSubdirectoriesFromRootToTarget = List.Skip(lstPathSubdirectories, numSegmentsFromHostToRoot),

        uriScheme = if Text.StartsWith(partsOrig[Scheme], "http") then partsOrig[Scheme] & "://" else partsOrig[Scheme],
        PathComponentsAll = List.Combine({ {uriScheme, partsOrig[Host]}, lstPathSubdirectories }),

        lstSegmentsToRoot = if numSegmentsFromHostToRoot = null then {} else List.Combine({ {partsOrig[Host]}, lstSubdirectoriesHostToRoot }),

        results = {
            fnMakeRecordForTable("PathFull", pathInput, "text", "Original full path"),
            fnMakeRecordForTable("LikelyContentType", fnGetLikelyContentType(pathInput), "text", "File or Folder (weak determination)"),
            fnMakeRecordForTable("LocationStorageType", LocationStorageType, "text", "OneDrive, SharepointTeams, Other, or null"),
            fnMakeRecordForTable("PathToRoot",
                Text.Combine({uriScheme, Text.Combine(lstSegmentsToRoot, PATH_DELIMITER), PATH_DELIMITER }),
                "text", "Full path to the root directory for the OneDrive personal or Sharepoint Teams site"),
            fnMakeRecordForTable("PathFromRoot",
                Text.Combine(lstSubdirectoriesFromRootToTarget, PATH_DELIMITER), 
                "text", "Path from the root directory to the target location"),
            fnMakeRecordForTable("PathComponentsAll", PathComponentsAll, "list (of text)", "List of path segments without any empty strings from leading/trailing slashes"),
            fnMakeRecordForTable("PathComponentsAllDecoded", fnDecodeSegments(PathComponentsAll), "list (of text)", "Same as PathComponentsAll but with URL-decoded text; e.g., %20 converted to space"),
            fnMakeRecordForTable("PathSegmentsToRoot", lstSegmentsToRoot, "list (of text)", "List of path segments from host to root directory"),
            fnMakeRecordForTable("PathSegmentsToRootDecoded", fnDecodeSegments(lstSegmentsToRoot), "list (of text)", "Same as PathSegmentsToRoot but with URL-decoded text; e.g., %20 converted to space"),
            fnMakeRecordForTable("PathSegmentsFromRoot", lstSubdirectoriesFromRootToTarget, "list (of text)", "List of path segments from root directory to target"),
            fnMakeRecordForTable("PathSegmentsFromRootDecoded", fnDecodeSegments(lstSubdirectoriesFromRootToTarget), "list (of text)", "Same as PathSegmentsFromRoot but with URL-decoded text; e.g., %20 converted to space"),
            fnMakeRecordForTable("URIParts", partsOrig, "record", "Record with URI parts")
        },
        resultTable = fnMakeResultTable(results),

        asTable = resultTable,
        asRecord = Record.FromList(resultTable[Value], resultTable[Key]),
        result = if returnType = null then asTable 
            else if Text.Lower(Text.From(returnType)) = "record" then asRecord
            else asTable
    in // end of main function
        result

in // end of full definition
    Value.ReplaceType(fnParseSharepointURL_INIT, docstring)