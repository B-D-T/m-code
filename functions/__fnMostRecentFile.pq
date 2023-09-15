(
    pPathToSourceFolder as text,
    optional pFileStem as text,
    optional pFileExtensionOfOutput as text,
    optional pSuffixDelimiter as text,
    optional pPostDateDelimiter as text,
    optional pPostDateDescriptor as text
) as binary =>

let
    // Variables for testing
    // pPathToSourceFolder = pathCSVExportsDir, pFileStem = "all_sport_divs", pFileExtensionOfOutput = "csv", pSuffixDelimiter = "__", pPostDateDelimiter = null, pPostDateDescriptor = null, 

    // This code is designed for a naming convenion of FileStem__yyyymmdd_Aaa.xxx or FileStem__yyyymmdd-hhmm_Aaa.xxx
        // FileStem : Anything that doesn't have the delimiter in it. Even spaces are okay.
        // __ (strSuffixDelimiter) : Any text string that isn't somewhere else in the file name. Even this can have spaces (but for f's sake, please don't do that)
        // yyyymmdd-hhmm : Date of output. This is what will determine which file to return.
        //                 The "-" can be anything, or omitted entirely since the code just pull the last four characters for the time.
        //                 The -hhmm is optional; the code will work if that's present, or ignore it if that's missing.
        // _ : separate the date from the data type abbreviation
        // Aaa (strDesiredDataTypeAbbr) : Either Txt or Num
        // . : Start of file type extension
        // xxx (strFileExtensionOfOutput) : File extension
    
    strPathToSourceFolder = pPathToSourceFolder,
    strFileExtensionOfOutput = if pFileExtensionOfOutput = null then "csv" else Text.Lower(pFileExtensionOfOutput),

    // This is the text that sets off the ending of the file name from the filename stem
    strSuffixDelimiter = if pSuffixDelimiter = null then "__" else pSuffixDelimiter,

    // This separates the date from anything after it. It does not have to be unique within the filename.
    strPostDateDelimiter = if pPostDateDelimiter = null then "." else pPostDateDelimiter,

    // A Qualtrics output file has the text values or the numeric values. This parameter looks for 'Txt' or 'Num' to distiguish which we want back. This can be null if there's only one data type in the folder. It can also be anything else, if you're using some other type of descriptor in the filename, but you might need to tweak this code if that's the case.
    strPostDateDescriptor = if pPostDateDescriptor = null then "" else Text.Lower(pPostDateDescriptor),

    
    SourceFolder = Folder.Files(strPathToSourceFolder),

    // Create a datetime value based on the naming convention of the CSVs
    fParseFilenameDateTime = (pFilename as text, optional pSuffixDelimiter as text, optional pPostDateDelimiter as text) as datetime =>
        let
            strFilename = pFilename, strSuffixDelimiter = pSuffixDelimiter, strPostDateDelimiter = pPostDateDelimiter,
            
            strFilenameDateTime = Text.BetweenDelimiters(strFilename, 
                if strSuffixDelimiter = null then "__" else strSuffixDelimiter ,
                if strPostDateDelimiter = null then "." else strPostDateDelimiter
                ),

            // Parse the date
            strFilenameDate = Text.Start(strFilenameDateTime, 8),
            // Parse the time, or use midnight if there is no time listed
            strFilenameTime = if Text.Length(strFilenameDateTime)=8 then "0000" else Text.End(strFilenameDateTime, 4),

            intYear = Number.From(Text.Start(strFilenameDate,4)),
            intMonth = Number.From(Text.Middle(strFilenameDate,4,2)),
            intDay = Number.From(Text.Middle(strFilenameDate,6,2)),
            intHour = Number.From(Text.Start(strFilenameTime,2)),
            intMinute = Number.From(Text.Middle(strFilenameTime,3,2)),

            dtFilename = #datetime(intYear,intMonth,intDay,intHour,intMinute,0)
        in
            dtFilename,

    // Filter file types to show only the ones we want
    FilteredForExtension = Table.SelectRows(SourceFolder, each Text.Lower([Extension]) = "." & strFileExtensionOfOutput ),
    
    // Filter for the file stem, which can be anywhere in the filename. The code just does a filter for it.
    FilteredForStem = if (pFileStem = null) or (pFileStem = "")
        then FilteredForExtension
        else Table.SelectRows(FilteredForExtension, each Text.Contains([Name], pFileStem)),

    // If there is not Descriptor, this will just return all files
    FilteredForDataDescriptor = if strPostDateDescriptor = ""
        then FilteredForStem
        else Table.SelectRows(FilteredForStem, each Text.EndsWith(Text.Lower([Name]), strPostDateDelimiter & strPostDateDescriptor & "." & strFileExtensionOfOutput) ), // "-Txt.csv"

    AddedFilenameDate = Table.AddColumn(FilteredForDataDescriptor, "FilenameDateTime", each fParseFilenameDateTime([Name], strSuffixDelimiter, strPostDateDelimiter), type datetime ),
    RemovedErrorsOnFileDatetime = Table.RemoveRowsWithErrors(AddedFilenameDate, {"FilenameDateTime"}),
    FilteredForMostRecent = Table.SelectRows(RemovedErrorsOnFileDatetime, let dtMostRecent = List.Max(RemovedErrorsOnFileDatetime[FilenameDateTime]) in each [FilenameDateTime] = dtMostRecent ),

    binFileToImport = FilteredForMostRecent[Content]{0}
in
    binFileToImport