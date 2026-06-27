{ prelude }:
let
  mkMatch =
    genSelect: condition: id: ctx:
    if condition ? __restricted then
      let
        origMatch = genSelect.matches condition.original id ctx;
        extraMatch = genSelect.matches condition.extra id ctx;
      in
      origMatch && extraMatch
    else
      genSelect.matches condition id ctx;

  selectorSpecificity =
    selector:
    let
      tag = selector.__sel;
    in
    if tag == "star" then
      0
    else if tag == "attrs" then
      builtins.length (builtins.attrNames selector.a)
    else if tag == "and" then
      prelude.foldl' (acc: s: acc + selectorSpecificity s) 0 selector.selectors
    else if tag == "any" then
      prelude.foldl' (acc: s: acc + selectorSpecificity s) 0 selector.selectors
    else if tag == "not" then
      selectorSpecificity selector.selector
    else if tag == "has" then
      1 + selectorSpecificity selector.selector
    else if tag == "within" then
      1 + selectorSpecificity selector.selector
    else if tag == "parentMatches" then
      1 + selectorSpecificity selector.selector
    else if tag == "when" then
      0
    else
      0;
in
{
  inherit mkMatch selectorSpecificity;
}
