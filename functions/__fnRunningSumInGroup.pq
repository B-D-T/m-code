//__fnRunningSumInGroup
// Source: https://www.myonlinetraininghub.com/grouped-running-totals-in-power-query
// This still needs work -- I just copied the code from the web. I'd like it to be more like my fnTableAddCountif function.

(values as list, grouping as list) as list =>

let 
    GRTList = List.Generate
    (
        ()=> [ GRT = values{0}, i = 0],

        each [i] < List.Count(values),

        each
            try if grouping{[i]} = grouping{[i] + 1}
                then [GRT = [GRT] + values{[i] + 1}, i = [i] + 1]
                else [GRT = values{[i] + 1}, i = [i] + 1]
            otherwise [i = [i] + 1]
    ,
        each [GRT]
        
    )
in
    GRTList