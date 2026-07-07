{ prelude }:
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
      group ? null,
    }:
    {
      inherit
        condition
        produce
        nac
        identity
        priority
        overrides
        group
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
        required = prelude.filter (k: !condition.${k}) (builtins.attrNames condition);
      in
      prelude.all (k: ctx ? ${k}) required;
in
{
  inherit mkRule fromFunction fromFunctionMatch;
}
