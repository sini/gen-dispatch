{ lib }:
let
  mkMatch =
    selectLib: condition: id: ctx:
    if condition ? __restricted then
      let
        origMatch = selectLib.matches condition.original id ctx;
        extraMatch = selectLib.matches condition.extra id ctx;
      in
      origMatch && extraMatch
    else
      selectLib.matches condition id ctx;

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
      lib.foldl' (acc: s: acc + selectorSpecificity s) 0 selector.selectors
    else if tag == "or" then
      lib.foldl' (acc: s: acc + selectorSpecificity s) 0 selector.selectors
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
