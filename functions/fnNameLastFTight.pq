/*
This code takes a list of names as input, removes spaces and special characters, and adds any initials (and any custom text). This can help with saving a file.
fnNameLastFTight({"B.", "David", "Tyler"}) returns "TylerBD"
fnNameLastFTight({"Zendaya", "de Newton-John, Jr."}) returns "DeNewtonJohnZ"

The listInputNamesFL is a list of names from first to last (given name -> family name). The last name is the only one required; the first initials for any other names will be added.
The optional listInputStringsToRemove argument is a list of additional CASE INSENSITIVE text to remove.
The optional listInputStringsToAppend argument is a list text to append.
*/

(listInputNamesFL as list, optional listInputStringsToRemove as list, optional listInputStringsToAppend as list) as text =>
    let
		listNamesFL = if listInputNamesFL is list then listInputNamesFL else {listInputNamesFL},
		listStringsToRemove = if listInputStringsToRemove is list then listInputStringsToRemove else {},
		listStringsToAppend = if listInputStringsToAppend is list then listInputStringsToAppend else {},

		// Get the last name
		strLastName = List.Last(listNamesFL),
		fnNameLastSimple = LibPQ("fnNameLastSimple"),
		strLastNameSimple = fnNameLastSimple(strLastName),
		
        // Creates a list of name part (lNP = lNameParts) by splitting on spaces and hyphens
        lNP = Text.SplitAny(strLastNameSimple," -"),

        // Remove special characters (periods, commas, hyphens, apostrophes)
        lNPNoSpecialChars = List.Transform(lNP, each Text.Remove(_, {".", ",", "-", "'"} ) ),

        // Remove empty rows
        lNPNoEmpties = List.RemoveMatchingItems(lNPNoSpecialChars, {"", " ", null} ),

        // Remove anything on listStringsToRemove
        lNPNoLNSuffixes = List.RemoveMatchingItems(lNPNoEmpties, listStringsToRemove, Comparer.FromCulture("en-US", true)),
		
		// Get full name initials
		listFirstNames = List.Range(listNamesFL , 0 , List.Count(listNamesFL)-1 ),
		listFirstInitials = List.Transform(listFirstNames, each Text.Upper(Text.Start(_ , 1) )  ),
		
		// Combine last name and first initials. If there aren't any initials, nothing will be added to the last name.
		listLastFirst = List.Combine({ lNPNoLNSuffixes, listFirstInitials }),
		
		// Append optional text strings
		listWithStringsToAppends = List.Combine({ listLastFirst, listStringsToAppend }),
	
		// Concatenate anything that's left.
        strNameFTight = Text.Combine(listWithStringsToAppends),
		
		// Replace any non en-US letters
		fnTextCharsToEng = LibPQ("fnTextCharsToEng"),
		strNoForeignChars = fnTextCharsToEng(strNameFTight)

    in
        strNoForeignChars