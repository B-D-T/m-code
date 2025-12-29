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
        Documentation.Version = "0.0.1",
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

MAIN_FUNCTION_INIT = (pathTarget as text) as table =>
    let
        // The "Simple" approach returns the URL as a directory path by ensuring it ends with a trailing slash.
        // The "Robust" approach attempts to access the path via SharePoint.Contents to confirm it is a valid directory.
        // Potential improvement: I wonder it would be better to go one step up and see if the final segment has Content=Binary.
        fnEnsurePathIsDirectory = (path as text, optional robust_method as logical) as text =>
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


        pathToParse = fnEnsurePathIsDirectory(pathTarget),
        urlComponents = fnParseSharepointURL(pathToParse, "record"),
        PathToRoot = urlComponents[PathToRoot],
        PathSegmentsFromRoot = urlComponents[PathSegmentsFromRoot],

        SharepointRootContents = SharePoint.Contents(PathToRoot, [ApiVersion = 15]),

        TargetDirectoryContents =
            try
                List.Accumulate(
                    PathSegmentsFromRoot,
                    SharepointRootContents,
                    (accumulator, folderName) => accumulator{[Name = folderName]}[Content]
                )
            catch (err) =>
                error [
                    Reason = "Invalid path provided",
                    Message = "
    This means you either... 
    A) Passed a file (remember that this only works for folders/ directories), or
    B) The code could not follow the path that you provided.
    Please double check that the path points to a valid SharePoint folder and you copied the full URL directly from the Path button in the browser.
    ",
                    Detail = err[Detail],
                    // Message.Format = err[Message.Format],
                    Message.Parameters = err[Message.Parameters],
                    ErrorCode = err[ErrorCode]
                ]
    in
        TargetDirectoryContents

in // end of full definition
    Value.ReplaceType(MAIN_FUNCTION_INIT, docstring)