/*
This code does its best to create a simplified last name from a "Last name" input, such as to use when saving a file.
E.g., If the last name field for "Zadaya de Newton-John, Jr." has "de Newton-John, Jr.", this function will return "DeNewtonJohn"
The list of suffixes/prefixes came from one online where there was a function for full names (https://stackoverflow.com/a/53732462/9312373)
*/

(strInputLastName as text) as text =>
    let
        listLastNameSuffixes = { "jr", "sr", "ii", "iii", "iv", "v", "esq", "cpa", "dc", "dds", "vm", "jd", "md", "phd" },
        //listLastNamePrefixes = { "da", "de", "del", "dos", "el", "la", "st", "van", "von" },
        
        // Creates a list of elements in the name by splitting on spaces and hyphens
        listNameParts = Text.SplitAny(strInputLastName," -"),
        lNP = listNameParts,

        // Remove special characters (periods, commas, hyphens, apostrophes)
        lNPNoSpecialChars = List.Transform(lNP, each Text.Remove(_, {".", ",", "-", "'"} ) ),

        // Remove empty rows
        lNPNoEmpties = List.RemoveMatchingItems(lNPNoSpecialChars, {"", " ", null}),

        // Make everything lowercase
        lNPLowercase = List.Transform(lNPNoEmpties, each Text.Lower(_) ),

        // Remove anything on the suffix list
        lNPNoLNSuffixes = List.RemoveMatchingItems(lNPLowercase, listLastNameSuffixes),

        // Anything that's left will be in the final output. Capitalize each entry, then concatenate it all
        lNPPropercase = List.Transform(lNPNoLNSuffixes, each Text.Proper(_) ),
        strNameLastTight = Text.Combine(lNPPropercase)       
    in
        strNameLastTight
