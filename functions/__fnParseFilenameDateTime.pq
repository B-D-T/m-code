(pFilename as text, optional pSuffixDelimiter as text, optional pSalestatusDelimiter as text) as datetime =>
let
    strFilename = pFilename, strSuffixDelimiter = pSuffixDelimiter, strSalestatusDelimiter = pSalestatusDelimiter,
    
    // The Sale Status and the date
    strFileNameStart = Text.BeforeDelimiter(strFilename, strSuffixDelimiter),

    strFilenameDateTime = Text.AfterDelimiter(strFileNameStart, strSalestatusDelimiter),

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
    dtFilename