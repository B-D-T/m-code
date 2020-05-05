// I don't remember the source for this code.
(HTML as text) =>
let
    Source = Text.From(HTML),
    SplitAny = Text.SplitAny(Source,"<>"),
    ListAlternate = List.Alternate(SplitAny,1,1,1),
    ListSelect = List.Select(ListAlternate, each _<>""),
    TextCombine = Text.Combine(ListSelect, "")
in
    TextCombine