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

  # `override { original; replacement; }` — two rules of one sort (P2, R7 (b)): one record, whose
  # field names carry the roles the argument order did. A door (open, as a record operand is), so a
  # missing rule is refused catchably, by name, at this application.
  override =
    prelude.door
      {
        name = "gen-dispatch.override";
        required = [
          "original"
          "replacement"
        ];
        open = true;
      }
      (
        { original, replacement, ... }:
        if original.identity == null then
          throw "gen-dispatch: cannot override anonymous rule"
        else
          replacement
          // {
            overrides = (replacement.overrides or [ ]) ++ [ original.identity ];
          }
      );

  # `chain extract ruleA ruleB` (P2, R7): `extract` was the one field of a record, and a record with
  # one required field is an operand, so it is positional and first (configuration); `ruleA` fires
  # before `ruleB`, which is the order the composite runs them in.
  chain = extract: ruleA: ruleB: {
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
  };
in
{
  inherit restrict override chain;
}
