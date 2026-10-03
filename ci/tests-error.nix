# THE SECOND TEST OUTPUT — cells whose subject is an ERROR.
#
# `gen-harness.lib.mkCi` builds `checks.default` from an asserter that forces every `t.expr` over
# `config.flake.tests` and nothing else, so a cell whose `expr` ABORTS crashes that gate rather than
# failing it. A cell asserting a refusal's TYPE and MESSAGE is exactly such a cell, so it lives on
# `flake.testsError`, entered through `extraModules` in `ci/flake.nix` (outside `testModules`), the
# same split gen-graph, gen-scope, gen-merge, gen-link, gen-resolve and gen-memo carry.
#
#   nix-unit --flake ./ci#tests        # the suite
#   nix-unit --flake ./ci#testsError   # these cells
#
# `msg` is a POSIX ERE, not a literal.
{
  genDispatch,
  genAlgebra,
  prelude,
  ...
}:
let
  inherit (genDispatch)
    mkRule
    dispatch
    chain
    deriveGroup
    ;
  fx = genDispatch.mkActions {
    structural = [ "spawn" ];
    resolution = [
      "edge"
      "drop"
    ];
  };

  # The message, pinned to the byte, in gen-prelude's own goldens' style
  # (`gen-prelude/ci/tests/door.nix`): `escapeRegex` neutralises metacharacters so the pattern reads
  # as the text as written, anchored at both ends against `expectedError.msg`'s SEARCH semantics.
  exactly = msg: "^" + prelude.escapeRegex msg + "$";
in
{
  flake.testsError.declared = {
    # `deriveGroup` is the DEFINITION-TIME stratum authority, so a typo in a ONE-kind `produces`
    # refuses when the derived rule is forced to WHNF — `seq`, never `deepSeq` and never a read of
    # `.group`. With one kind, `unique` never compares its element, so the classification is only
    # forced if `deriveGroup` forces it; the refusal is `classifyKind`'s own named throw.
    test-deriveGroup-single-unknown-kind-refuses-at-definition = {
      expr = builtins.seq (deriveGroup fx.groupOfKind (
        mkRule {
          produces = [ "bogus" ];
          identity = "typo";
        } { } (_: _: [ ])
      )) true;
      expectedError = {
        type = "ThrownError";
        msg = "gen-dispatch: unknown action tag 'bogus'";
      };
    };
  };

  # ── THE DOOR BYTES (den-hoag-7gp66 P1, reshaped by P2) — R6's naming, pinned per door.
  # `ci/tests/door-checks.nix` pins that each door's violations are CATCHABLE; a boolean cannot see
  # WHICH refusal fired, so WHICH is pinned here. After P2 the options are a closed set of their own,
  # first (`mkRule`, `dispatch`); `dispatch`'s operands and `override`'s two rules are open record
  # doors, so each carries a missing-field golden and no unknown-field one (R5's admitted case).
  # `mkRule`'s `condition`/`produce` and `chain`'s `extract` are positional: their arity is
  # structural, so they have no field to be missing.
  flake.testsError.door-checks = {
    test-mkrule-unknown-option-message = {
      expr = mkRule { zzqran7f = 1; };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.mkRule: 'zzqran7f' is not an option of this door; the options are closed (accepted: 'nac', 'identity', 'priority', 'overrides', 'group', 'produces') (in prelude.checkOptions)";
      };
    };

    test-dispatch-missing-operand-message = {
      expr = dispatch { } {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.dispatch: required field 'groupOrder' is missing (required: 'rules', 'id', 'context', 'match', 'classify', 'groupOrder') (in prelude.checkRequired)";
      };
    };
    test-dispatch-unknown-option-message = {
      expr = dispatch { zzqran7f = 1; };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.dispatch: 'zzqran7f' is not an option of this door; the options are closed (accepted: 'exclusive', 'extract', 'combine') (in prelude.checkOptions)";
      };
    };
    # An operand placed in the options position, the old one-record call shape, is refused by name
    # at the options application.
    test-dispatch-old-one-record-shape-message = {
      expr = dispatch {
        rules = [ ];
        exclusive = true;
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.dispatch: 'rules' is not an option of this door; the options are closed (accepted: 'exclusive', 'extract', 'combine') (in prelude.checkOptions)";
      };
    };

    # G10 (v1.2, den-hoag-7gp66 premise 7): an option of `dispatch`'s own options step, given on the
    # operand record instead, is refused by name — `checkGuarded`'s own message, not `checkOptions`'s.
    test-dispatch-misplaced-option-message = {
      expr = dispatch { } {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
        groupOrder = [ "g" ];
        exclusive = true;
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.dispatch: 'exclusive' is an option of gen-dispatch.dispatch, not a field of this record (in prelude.checkGuarded)";
      };
    };

    # a rule built from a registered construction has no override handle, and `override` names that
    test-override-of-a-registered-rule-is-refused-by-name = {
      expr = genDispatch.override {
        original = genDispatch.fromFunction (
          genAlgebra.mkIntensional
            (
              _: _: _:
              throw "no digest"
            )
            {
              revision = "r1";
              members.r = _a: { host, ... }: [ ];
            }
            "r"
            { }
        );
        replacement = mkRule { } { } (_id: _ctx: [ ]);
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch: cannot override anonymous rule";
      };
    };

    test-override-missing-rule-message = {
      expr = genDispatch.override { original = mkRule { } { } (_id: _ctx: [ ]); };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.override: required field 'replacement' is missing (required: 'original', 'replacement') (in prelude.checkRequired)";
      };
    };

    # LIVE CONTROL, same run, same output: a well-formed call on each door answers rather than
    # throwing — the vacuity every cell above asserting a refusal invites, discharged here.
    test-control-mkrule-well-formed-call-answers = {
      expr = (mkRule { } { } (_id: _ctx: [ ])).priority;
      expected = 0;
    };
    test-control-chain-well-formed-call-answers = {
      expr =
        let
          r = mkRule { } { } (_id: _ctx: [ ]);
        in
        (chain (_actions: { }) r r).identity;
      expected = null;
    };
  };
}
