/*
Converts foreign characters in a text string to en-US
fnTextCharsToEng("Dãvid") returns "David"

*/

(strInputText as text) =>
let
	
	tblCharsToCheck = Table.FromList( Text.ToList(strInputText) , null, {"OrigChars"} ),
	
	// Merge with tblCharsNonEng
	tblCharsNonEng = LibPQ("tblCharsNonEng"),
	MergedWithCharsTbl = Table.NestedJoin(tblCharsToCheck, {"OrigChars"}, tblCharsNonEng, {"NonEngChar"}, "CharConvertTable", JoinKind.LeftOuter),
    AddedNewCharsCol = Table.AddColumn(MergedWithCharsTbl, "NewChars", each try [CharConvertTable][EngChar]{0} otherwise [OrigChars], type text),
	
	// Reconstitute the text string
	strCleanString = Text.Combine(AddedNewCharsCol[NewChars])

in
	strCleanString