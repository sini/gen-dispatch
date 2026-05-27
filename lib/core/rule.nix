{ lib, genAlgebra }:
let
  isIntensional = v: builtins.isAttrs v && v ? name && v ? __functor && v ? closure;

  mkRule =
    {
      condition,
      produce,
      nac ? null,
      identity ? null,
      priority ? 0,
      overrides ? [ ],
    }:
    {
      inherit
        condition
        produce
        nac
        identity
        priority
        overrides
        ;
    };

  fromFunction =
    fn:
    let
      args = builtins.functionArgs fn;
    in
    mkRule {
      condition = args;
      produce = _id: ctx: fn ctx;
      identity = if isIntensional fn then fn.name else null;
    };

  fromFunctionMatch =
    condition: id: ctx:
    if condition ? __restricted then
      fromFunctionMatch condition.original id ctx && fromFunctionMatch condition.extra id ctx
    else
      let
        required = lib.filter (k: !condition.${k}) (builtins.attrNames condition);
      in
      lib.all (k: ctx ? ${k}) required;
in
{
  inherit mkRule fromFunction fromFunctionMatch;
}
