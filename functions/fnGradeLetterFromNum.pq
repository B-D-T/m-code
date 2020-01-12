/* 
	Converts a numerical value into a letter grade based on the provided grading scale table
	
	For example, fLetterGrade(0.65, "tblGradeScaleABCF") --> "F"
	
	*/

let
fn =
	( numToLookup as any, strGradingScaleToUse as text) as text =>
    let
		// This tries to pull in one of the standard grading scales that I've stored in the shared repository.
		// If it can't find anything by that name, it will look within the current workbook for a table with that name.
		// Thus, to set a custom grading scale, just create a table within the current workbook with a unique name and call it using the strGradingScaleToUse argument.
		GradeScaleTable = try LibPQ(strGradingScaleToUse) otherwise Excel.CurrentWorkbook(){[Name=strGradingScaleToUse]}[Content],
		
		// This selects the last row of the table where the "Lower" column's value is <= the score. (the "Upper" is irrelevant could be blank if we wanted)
		// It returns the value from the "Grade" field.
		strLetterGrade = Table.Last(
			Table.SelectRows(
				GradeScaleTable, 
				each ([Lower] <= Number.From(numToLookup) )
			)
		)[LetterGrade]
	in
		strLetterGrade,

fnType = type function
    (
		numToLookup as (type any meta 
			[
				Documentation.FieldCaption = "Decimal score to look up",
				Documentation.FieldDescription = "Enter number as decimal",
				Documentation.SampleValues = { "0.65, .65, or 65% will work" }
			]
		),
		strGradingScaleToUse as (type text meta
			[ 
				Documentation.AllowedValues = {"tblGradeScaleGeneral", "tblGradeScaleABCF"}
			]
		)
	) as list
in
    Value.ReplaceType( 
        fn, fnType
    )