// tblGradeScaleGradUMass.pq
// Similar to general scale, but anything lower than a C is a F (no C- or D grades)
// Used for most graduate school grading.

#table(
type table
    [
        #"Lower"=number,
        #"Upper"=number,
        #"LetterGrade"=text,
        #"Midpoint"=number,
		#"GPAPts"=number
    ],
 {
  { 0.0000 , 0.7249 , "F" , 0.3625, 0.0 },
  { 0.7250 , 0.7649 , "C" , 0.7450, 2.0 },
  { 0.7650 , 0.7949 , "C+", 0.7800, 2.3 },
  { 0.7950 , 0.8249 , "B-", 0.8100, 2.7 },
  { 0.8250 , 0.8649 , "B" , 0.8450, 3.0 },
  { 0.8650 , 0.8949 , "B+", 0.8800, 3.3 },
  { 0.8950 , 0.9249 , "A-", 0.9100, 3.7 },
  { 0.9250 , 1000.0 , "A" , 0.9625, 4.0 }
 }
)
