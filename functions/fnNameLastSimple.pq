/*
This code creates a simplified last name from a "Last name" input. Mostly it just removes any suffix.
The second argument is an optional list of CASE INSENSITIVE text strings to remove. E.g., if your list has lots of people with LMHC/LPC as a suffix, you could add that in the list.
Common string to remove include special characters (periods, commas, hyphens, apostrophes); i.e.,  {".", ",", "-", "'"}
Only "freestanding" text will be removed (i.e., text that is not part of another word).

fnNameLastSimple("de Newton-John, Jr.") returns "de Newton-John"
fnNameLastSimple("de Newton-John, Jr., LMHC/LPC", {"de", "-", "LMHC/LPC"}) returns "NewtonJohn" [although it would have been removed anyway since we cut off at the comma]
fnNameLastSimple("de Newton-John LMHC/LPC", {"LMHC"}) returns "de Newton-John LMHC/LPC" (no change because LMHC was connected to a larger text string)

The list of suffixes/prefixes came from one online where there was a function for full names (https://stackoverflow.com/a/53732462/9312373)
*/

(strInputLastName as text, optional listInputStringsToRemove as list) as text =>
    let
        listStringsToRemove = if listInputStringsToRemove is list then listInputStringsToRemove else {},
        listLastNameSuffixes = { "jr", "sr", "ii", "iii", "iv", "v", "esq", "cpa", "dc", "dds", "vm", "jd", "md", "phd" },
        //listLastNamePrefixes = { "da", "de", "del", "dos", "el", "la", "st", "van", "von" },
                
		// Remove any text after a comma. I THINK it's safe to say we don't want that.
		namePreComma = Text.Split(strInputLastName, ","){0},
		
        // Creates a list of name part (lNP = lNameParts) by splitting on spaces
        lNP = Text.SplitAny(namePreComma," "),

        // Remove extra text strings as defined by the function arguments
        lNPNoExtraStrings = List.RemoveMatchingItems(lNP, listStringsToRemove , Comparer.FromCulture("en-US", true)),

        // Remove empty rows
        lNPNoEmpties = List.RemoveMatchingItems(lNPNoExtraStrings, {"", " ", null}),

        // Remove anything on the suffix list. The true argument in the Comparer function is for ignoreCase so it will match PhD and phd
        lNPNoLNSuffixes = List.RemoveMatchingItems(lNPNoEmpties, listLastNameSuffixes, Comparer.FromCulture("en-US", true)),

        // Anything that's left will be in the final output, separated by spaces
        strNameLastSimple = Text.Combine(lNPNoLNSuffixes, " ")
    in
        strNameLastSimple