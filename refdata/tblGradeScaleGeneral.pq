// tblGradeScaleGeneral.pq
// Grading scale table with A+ through F
// Used for most undergraduate grading.

#table(
type table
    [
        #"Lower"			=	number,
        #"Upper"			=	number,
        #"LetterGrade"		=	text,
        #"Midpoint"			=	number,
		#"QualtricsNumVal" 	= 	number
    ],
 {
	{ 0.0000 , 0.5949 , "F" , 0.2975 , 1 },
	{ 0.5950 , 0.6249 , "D-" , 0.6100 , 2 },
	{ 0.6250 , 0.6649 , "D" , 0.6450 , 3 },
	{ 0.6650 , 0.6949 , "D+" , 0.6800 , 4 },
	{ 0.6950 , 0.7249 , "C-" , 0.7100 , 5 },
	{ 0.7250 , 0.7649 , "C" , 0.7450 , 6 },
	{ 0.7650 , 0.7949 , "C+" , 0.7800 , 7 },
	{ 0.7950 , 0.8249 , "B-" , 0.8100 , 8 },
	{ 0.8250 , 0.8649 , "B" , 0.8450 , 9 },
	{ 0.8650 , 0.8949 , "B+" , 0.8800 , 10 },
	{ 0.8950 , 0.9249 , "A-" , 0.9100 , 11 },
	{ 0.9250 , 0.9649 , "A" , 0.9450 , 12 },
	{ 0.9650 , 1000.0000 , "A+" , 0.9825 , 13 }
 }
)