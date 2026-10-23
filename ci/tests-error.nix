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
    fromFunction
    fromFunctionMatch
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
  # gen-prelude's refusal text, composed with this library's own literal door, field and accepted
  # set (den-hoag-7jltk): every assertion kept, none of gen-prelude's wording copied.
  inherit (prelude) refusals;

  # `produce : id -> ctx -> [ action ]`: a result that is not a list is refused by name where the
  # group's actions are read (the tail is the same at every site).
  notAList =
    who:
    exactly "gen-dispatch: rule ${who} produced a set, not a list of actions (produce : id -> ctx -> [ action ]; return one action as [ action ])";
  structural =
    rules:
    (dispatch { } {
      inherit rules;
      id = null;
      context = {
        host = 1;
      };
      match = fromFunctionMatch;
      inherit (fx) classify;
      groupOrder = [ "structural" ];
    }).actions.structural;
  oneAction = kind: fx.spawn { inherit kind; };
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

  # `unique` (den-hoag-ro5cu): two rules surviving the exclusive filter refuse by NAME — the group and
  # both identities — when the group's actions are read.
  flake.testsError.conflict = {
    test-unique-two-survivors-refused-by-name = {
      expr =
        (dispatch
          {
            exclusive = true;
            unique = true;
          }
          {
            rules = map (v: mkRule { identity = v; } { } (_id: _ctx: [ (fx.spawn { inherit v; }) ])) [
              "hem-a"
              "hem-b"
            ];
            id = null;
            context = { };
            match =
              _cond: _id: _ctx:
              true;
            inherit (fx) classify;
            groupOrder = [ "structural" ];
          }
        ).actions.structural;
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch: unique dispatch of group \"structural\" has 2 surviving rules: hem-a, hem-b";
      };
    };
  };

  flake.testsError.single-effect = {
    # undeclared path: `classify` would have read the result, and aborted uncatchably
    test-fromFunction-single-action-refused-by-name = {
      expr = structural [ (fromFunction ({ host, ... }: oneAction "a")) ];
      expectedError = {
        type = "ThrownError";
        msg = notAList "\"anonymous\" in group \"structural\"";
      };
    };

    # declared path: `classify` never runs, so this refusal is the only one
    test-declared-single-action-refused-by-name = {
      expr = structural [
        (mkRule {
          identity = "decl";
          produces = [ "spawn" ];
        } { host = false; } (_: _: oneAction "d"))
      ];
      expectedError = {
        type = "ThrownError";
        msg = notAList "\"decl\" in group \"structural\"";
      };
    };

    # `chain` concatenates its arms inside its own `produce`, before dispatch sees a result
    test-chain-arm-single-action-refused-by-name = {
      expr = structural [
        (chain (_: { }) (mkRule { identity = "ca"; } { host = false; } (_: _: oneAction "ca")) (
          mkRule { identity = "cb"; } { host = false; } (_: _: [ (oneAction "cb") ])
        ))
      ];
      expectedError = {
        type = "ThrownError";
        msg = notAList "\"ca\" (chain arm A)";
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
        msg = exactly (
          refusals.unknownOption "gen-dispatch.mkRule" [
            "nac"
            "identity"
            "priority"
            "overrides"
            "group"
            "produces"
          ] "zzqran7f"
        );
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
        msg = exactly (
          refusals.missingField "gen-dispatch.dispatch" [
            "rules"
            "id"
            "context"
            "match"
            "classify"
            "groupOrder"
          ] "groupOrder"
        );
      };
    };
    test-dispatch-unknown-option-message = {
      expr = dispatch { zzqran7f = 1; };
      expectedError = {
        type = "ThrownError";
        msg = exactly (
          refusals.unknownOption "gen-dispatch.dispatch" [
            "exclusive"
            "unique"
            "extract"
            "combine"
          ] "zzqran7f"
        );
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
        msg = exactly (
          refusals.unknownOption "gen-dispatch.dispatch" [ "exclusive" "unique" "extract" "combine" ] "rules"
        );
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
        msg = exactly (refusals.guardedField "gen-dispatch.dispatch" "gen-dispatch.dispatch" "exclusive");
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
        msg = exactly (
          refusals.missingField "gen-dispatch.override" [ "original" "replacement" ] "replacement"
        );
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
