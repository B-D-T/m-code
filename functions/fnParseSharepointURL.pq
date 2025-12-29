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
        Documentation.Version = "0.0.1",
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

// Function with notes to the developer about working with paths. These don't do anything, but they're here for reference.
fnDevInfo = () as table =>
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
InfoTableForDeveloper = fnDevInfo(),

// MAIN FUNCTION STARTS HERE
MAIN_FUNCTION_INIT = (pathInput as text, optional returnType as text) =>
    let
        PATH_DELIMITER = "/",

        partsOrig = Uri.Parts(pathInput),
        partsHost = Text.Lower(partsOrig[Host]),

        // File or Folder, but it's a weak determination based on path ending in "/" or not
        LikelyContentType = if pathInput = null then null
            else if Text.EndsWith(pathInput, PATH_DELIMITER) then "Folder" else "File",

        // LocationStorageType is "OneDrive", "SharepointTeams", "Other", or null (for now). 
        // I can't determine how to accurately differentiate SharepointMain from SharepointChannel yet.
        // In theory, I could look for "General" as one of the first subdirectories, but that's not ALWAYS going to work.
        LocationStorageType = if (partsHost = null) then null 
            else if partsHost = "" then null
            else if Text.EndsWith(partsHost, "-my.sharepoint.com") then "OneDrive"
            else if Text.EndsWith(partsHost, "sharepoint.com") then "SharepointTeams"
            else "Other",
        
        // Create list of path segments, ignoring any leading/trailing slashes
        lstPathSubdirectories = Text.Split(Text.Trim(partsOrig[Path], PATH_DELIMITER), PATH_DELIMITER),

        numSegmentsFromHostToRoot = 
            if LocationStorageType = null then null 
            else if LocationStorageType = "OneDrive" then 2
            else if LocationStorageType = "SharepointTeams" then 2
            else 0, // Unknown; return just the host
        lstSubdirectoriesHostToRoot = List.FirstN(lstPathSubdirectories, numSegmentsFromHostToRoot),
        lstSubdirectoriesFromRootToTarget = List.Skip(lstPathSubdirectories, numSegmentsFromHostToRoot),

        uriScheme = if Text.StartsWith(partsOrig[Scheme], "http") then partsOrig[Scheme] & "://" else partsOrig[Scheme],
        PathComponentsAll = List.Combine({
            {uriScheme, partsOrig[Host]},
            lstPathSubdirectories
        }),

        lstSegmentsToRoot = if numSegmentsFromHostToRoot = null then {}
            else List.Combine({{partsOrig[Host]}, lstSubdirectoriesHostToRoot}),
        strPathToRoot = Text.Combine({
            uriScheme,
            Text.Combine(lstSegmentsToRoot, PATH_DELIMITER), 
            PATH_DELIMITER // always end with a slash to indicate a directory
        }, null),
        strPathFromRoot = Text.Combine(lstSubdirectoriesFromRootToTarget, PATH_DELIMITER),

        results = {
            [
                Key = "PathFull",
                Value = pathInput,
                DataType = "text",
                Description = "Original full path"
            ],
            [
                Key = "LikelyContentType",
                Value = LikelyContentType,
                DataType = "text",
                Description = "File or Folder (weak determination)"
            ],
            [
                Key = "LocationStorageType",
                Value = LocationStorageType,
                DataType = "text",
                Description = "OneDrive, SharepointTeams, Other, or null"
            ],
            [
                Key = "PathToRoot",
                Value = strPathToRoot,
                DataType = "text",
                Description = "Full path to the root directory for the OneDrive personal or Sharepoint Teams site"
            ],
            [
                Key = "PathFromRoot",
                Value = strPathFromRoot,
                DataType = "text",
                Description = "Path from the root directory to the target location"
            ],
            [
                Key = "PathComponentsAll",
                Value = PathComponentsAll,
                DataType = "list (of text)",
                Description = "List of path segments without any empty strings from leading/trailing slashes"
            ],
            [
                Key = "PathSegmentsToRoot",
                Value = lstSegmentsToRoot,
                DataType = "list (of text)",
                Description = "List of path segments from host to root directory"
            ],
            [
                Key = "PathSegmentsFromRoot",
                Value = lstSubdirectoriesFromRootToTarget,
                DataType = "list (of text)",
                Description = "List of path segments from root directory to target"
            ],
            [
                Key = "URIParts",
                Value = partsOrig,
                DataType = "record",
                Description = "Record with URI parts"]
        },
        resultTable = Table.TransformColumnTypes(Table.FromRecords(results),
            {
                {"Key", type text},
                {"DataType", type text},
                {"Description", type text}
            }
        ),
        asTable = resultTable,
        asRecord = Record.FromList(resultTable[Value], resultTable[Key]),
        result = if returnType = null then asTable 
            else if Text.Lower(Text.From(returnType)) = "record" then asRecord
            else asTable
    in // end of main function
        result

in // end of full definition
    Value.ReplaceType(MAIN_FUNCTION_INIT, docstring)
