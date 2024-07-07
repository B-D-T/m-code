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
		#"GPAPoints"		=	number,
		#"QualtricsNumVal" 	= 	number
    ],
 {
	{ 0.0000 , 0.5949 , "F" 	,	0.2975 , 0.0 , 1 },
	{ 0.6250 , 0.6649 , "D" 	, 	0.6450 , 1.0 , 3 },
	{ 0.6650 , 0.6949 , "D+" 	,	0.6800 , 1.3 , 4 },
	{ 0.6950 , 0.7249 , "C-" 	,	0.7100 , 1.7 , 5 },
	{ 0.7250 , 0.7649 , "C" 	, 	0.7450 , 2.0 , 6 },
	{ 0.7650 , 0.7949 , "C+" 	, 	0.7800 , 2.3 , 7 },
	{ 0.7950 , 0.8249 , "B-" 	, 	0.8100 , 2.7 , 8 },
	{ 0.8250 , 0.8649 , "B" 	, 	0.8450 , 3.0 , 9 },
	{ 0.8650 , 0.8949 , "B+" 	, 	0.8800 , 3.3 , 10 },
	{ 0.8950 , 0.9249 , "A-"	, 	0.9100 , 3.7 , 11 },
	{ 0.9250 , 0.9649 , "A"		, 	0.9450 , 4.0 , 12 },
	{ 0.9650 , 1000.0 , "A+"	, 	0.9825 , 4.0 , 13 }
 }
)