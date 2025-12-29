// fnGetSharepointContents.pq 
// Requires that fnParseSharepointURL is also available in the Power Query environment.

let 

// Documentation for the main function - this replaces the type information for the function to show type hints in the Power Query Editor
docstring = type function (
    // Metadata for the parameters
    pathTarget as (
        type text meta [
            Documentation.FieldCaption = "Full URL path as a text string",
            Documentation.FieldDescription = "Required. The full SharePoint/OneDrive URL to the directory for which you want the contents. 
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
    )
    ) as table
    // Metadata for the function itself
    meta [
        Documentation.Name = "fnGetSharepointContents",
        Documentation.Description = "Retrieves the contents of a SharePoint or OneDrive directory specified by URL.",
        Documentation.LongDescription = "
        Given a full SharePoint or OneDrive URL to a directory, this function retrieves the contents of that directory as a table.
        This is like using SharePoint.Contents, but it handles the navigation through the folder structure automatically based on the provided URL.
        This works for both SharePoint site document libraries and individual OneDrive folders.
        ",
        Documentation.Author = "B. David Tyler",
        Documentation.Version = "0.0.2",
        Documentation.Examples = {
            [
                Description = "Retrieve contents of a SharePoint folder",
                Code = "fnGetSharepointContents(""https://contoso.sharepoint.com/sites/MyTeam/Shared%20Documents/General/MySubdirectory/"")",
                Result = "(a table with the contents of the MySubdirectory Sharepoint folder)"
            ],
            [
                Description = "Retrieve contents of a OneDrive folder",
                Code = "fnGetSharepointContents(""https://contoso-my.sharepoint.com/personal/my_user_name/Documents/MySubdirectory/"")",
                Result = "(a table with the contents of the MySubdirectory OneDrive folder)"
            ]
        }
    ],


// The "Simple" approach returns the URL as a directory path by ensuring it ends with a trailing slash.
// The "Robust" approach attempts to access the path via SharePoint.Contents to confirm it is a valid directory.
fnEnsurePathIsDirectory = (path as text, optional robust_method as logical) as text =>
    // Potential improvement: I wonder it would be better to go one step up and see if the final segment has Content=Binary.
    let
        approach = if (robust_method = true or robust_method = null) then "robust" else "simple",
        PATH_DELIMITER = "/",

        // This is the result for the "simple" approach
        pathWithTrailingSlash = if Text.EndsWith(path, PATH_DELIMITER) then path else path & PATH_DELIMITER,

        urlComponents = fnParseSharepointURL(path, "record"),
        PathToRoot = urlComponents[PathToRoot],

        resultRecord = try SharePoint.Contents(PathToRoot, [ApiVersion = 15]), 
        resultRobust = if resultRecord[HasError] = false
            then pathWithTrailingSlash
            else error resultRecord[Error],

        result = if approach = "simple" then pathWithTrailingSlash else resultRobust
    in
        result,

// This receives an error record raised by the code and returns a new error record with a more user-friendly message.
fnCreateErrorRec_InvalidPath = (err as record) as record => [
    Reason = "Invalid path provided",
    Message = "
    This probably means one of the following:  
      A) The code failed as a result of shoddy coding on my part.
      B) You passed the path to a file instead of to a folder/ directory.
      or
      C) The code could not follow the path that you provided.  
    Please copied the full URL directly from the Path button in the browser and try pasting the path again.
    ",
    Detail = err[Detail],
    // Message.Format = err[Message.Format],
    Message.Parameters = err[Message.Parameters],
    ErrorCode = err[ErrorCode]
],
// This is just SharePoint.Contents, but I could add some better error handling or logging 
fnConnectToSharepointRoot = (pathToRoot as text) as table =>
    let
        result = try SharePoint.Contents(pathToRoot, [ApiVersion = 15]),
        SharepointRootContents = if result[HasError] = false
            then result[Value]
            else error result[Error]
    in
        SharepointRootContents,
// Navigate through the folder structure to get to the target directory contents
fnNavigateToTargetDirectory = (rootContents as table, pathSegments as list) as table =>
    // This is the main value of the entire module.
    // This step uses an accumulator to iterate through the folder structure
    // as if the user were clicking on Table, Content, Table, Content, etc.
    // It doesn't actually accumulate - it just drills down through the folder structure.
    let
        fnMoveToNextFolder = (currentContents as table, folderName as text) as table =>
            currentContents{[Name = folderName]}[Content],

        TargetDirectoryContents =
            try
                List.Accumulate(
                    pathSegments,
                    rootContents,
                    (acc, curFolder) => fnMoveToNextFolder(acc, curFolder)
                )
            catch (err) =>
                error fnCreateErrorRec_InvalidPath(err)
    in
        TargetDirectoryContents,

// MAIN FUNCTION; i.e., what gets invoked when the user calls the function
fnGetSharepointContents_INIT = (pathTarget as text) as table => 
    let
        pathToParse = fnEnsurePathIsDirectory(pathTarget),
        urlComponents = fnParseSharepointURL(pathToParse, "record"),
        
        rootContents = fnConnectToSharepointRoot(urlComponents[PathToRoot]),
        pathSegments = urlComponents[PathSegmentsFromRootDecoded],
        TargetDirectoryContents = fnNavigateToTargetDirectory(rootContents,pathSegments)
    in
        TargetDirectoryContents

in // end of full definition
    Value.ReplaceType(fnGetSharepointContents_INIT, docstring)
