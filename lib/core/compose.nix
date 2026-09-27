{ prelude }:
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

  # RECORD class (den-hoag-7gp66 P1, R5): `extract` is the only field, so a missing one was a
  # native abort past `tryEval` (ADR-0025 item 1); `checkRequired` (gate C3) makes that refusal
  # NAMED and CATCHABLE. `chain` stays curried in `ruleA`/`ruleB` — those are positional and out of
  # P1's scope, which covers only the leading attrset-destructured formal. `builtins.seq` forces
  # the check at THIS application, against `args` — not deferred to when the curried composite
  # eventually fires `produce`, which is the only site that would otherwise read `extract` at all.
  chain =
    args:
    let
      extract = (prelude.checkRequired "gen-dispatch.chain" [ "extract" ] args).extract;
    in
    builtins.seq extract (
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
        # EITHER ARM NULL ⇒ NULL. A composite is anonymous the moment ANY of its arms is,
        # because the arm with no identity is the one whose distinct rules the handle can
        # no longer tell apart. Defaulting a null arm to a constant hands two
        # behaviourally distinct composites ONE handle, and `override` accepts it without
        # complaint precisely because it is non-null — a silent wrong-rule override.
        #
        # The MIXED pair is what forces this scope rather than the anonymous one: a rule
        # that propagates null only when BOTH arms are anonymous still collides
        # `chain(identified X, anonymous A)` with `chain(identified X, anonymous B)`.
        # `restrict` already maps null to null and its prefix is injective on non-null
        # identities, so of the three composite paths only `chain` defaulted.
        #
        # A composite INHERITS its arms' regime tags rather than adding one of its own:
        # `rule.nix` emits `m:`/`u:` on every handle it derives, so those tags survive
        # into the composite unchanged and the two derived arms stay disjoint here too.
        # KNOWN RESIDUAL, inherited and not introduced by that tagging: this rendering is
        # a bare concatenation, so arms whose own identities contain `:` can in principle
        # render two different pairs alike. That predates the tags and belongs to the
        # composite's own encoding, not to the regime dispatch.
        identity =
          if ruleA.identity == null || ruleB.identity == null then
            null
          else
            "chain:${ruleA.identity}:${ruleB.identity}";
      }
    );
in
{
  inherit restrict override chain;
}
