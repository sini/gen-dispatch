{ ... }:
let
  restrict =
    extraCondition: rule:
    rule
    // {
      condition = {
        __restricted = true;
        original = rule.condition;
        extra = extraCondition;
      };
      identity = if rule.identity != null then "restricted:${rule.identity}" else null;
    };

  override =
    original: replacement:
    if original.identity == null then
      throw "gen-dispatch: cannot override anonymous rule"
    else
      replacement
      // {
        overrides = (replacement.overrides or [ ]) ++ [ original.identity ];
      };

  chain =
    { extract }:
    ruleA: ruleB: {
      inherit (ruleA) condition nac priority;
      overrides = (ruleA.overrides or [ ]) ++ (ruleB.overrides or [ ]);
      produce =
        id: ctx:
        let
          actionsA = ruleA.produce id ctx;
          feedback = extract actionsA;
        in
        actionsA ++ ruleB.produce id (ctx // feedback);
      identity =
        let
          a = if ruleA.identity != null then ruleA.identity else "anon";
          b = if ruleB.identity != null then ruleB.identity else "anon";
        in
        "chain:${a}:${b}";
    };
in
{
  inherit restrict override chain;
}
