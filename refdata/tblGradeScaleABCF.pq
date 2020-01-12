// Grading scale table with only A, B, C, and F
// Used for WCU graduate school grading, among other places.

#table(
type table
    [
        #"Lower"=number,
        #"Upper"=number,
        #"LetterGrade"=text,
        #"Midpoint"=number
    ],
 {
  { 0.0000 ,    0.6949 		,     "F", 	0.34745},
  { 0.6950 ,    0.7949 		,     "C", 	0.74495},
  { 0.7950 ,	0.8949		,     "B", 	0.74495},
  { 0.8950 ,	1000.000 	,     "A", 	0.74495}
 }
)