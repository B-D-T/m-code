/* This takes a list and makes it into a serialized text string. For example, 
 {"Larry", "Curly", "Moe"} --> "Larry, Curly, and Moe"
 {1, 2} --> "1 and 2"
 {"Alone"} --> "Alone"
*/

(inputList as list) as text =>
    let
        listCount = List.Count(inputList),

        // Make sure that the list is text
        listAsText = List.Transform(inputList, each Text.From(_)),

        // Add "and" in the penultimate position
        listWithAnd = if listCount>1 then List.InsertRange(listAsText, listCount-1,{"and"}) else listAsText,

        // For any list of 3 or more, add commas at the ends of each value other than the last two.
        // In George|Ringo|Paul|and|John, the last 2 values are "and" and "John". (listCount + 1 is to account for the "and")
        // The ampersand rejoins the editted values with the last two values.
        listSerialized = if listCount<=2 then listWithAnd else 
		List.Transform( 
			List.FirstN(
				listWithAnd, 
				listCount + 1 - 2
			), 
			each _ & ",")
        &		
        List.LastN(
			listWithAnd, 2
		),
        
        // Create a single text string with the list
        strSerializedList = Text.Combine(listSerialized," ")
		
    in
        strSerializedList