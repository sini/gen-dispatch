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
      expr = builtins.seq (deriveGroup fx.groupOfKind (mkRule {
        condition = { };
        produce = _: _: [ ];
        produces = [ "bogus" ];
        identity = "typo";
      })) true;
      expectedError = {
        type = "ThrownError";
        msg = "gen-dispatch: unknown action tag 'bogus'";
      };
    };
  };

  # ── THE DOOR-CHECK BYTES (den-hoag-7gp66 P1) — R6's naming, pinned per door. `ci/tests/door-
  # checks.nix` pins that each door's violations are CATCHABLE; a boolean cannot see WHICH refusal
  # fired, so WHICH is pinned here, one golden per violation type per door. `chain` (RECORD class)
  # carries only the missing-field golden: an unknown field is R5's admitted case, and
  # `ci/tests/door-checks.nix` already pins that it does not throw.
  flake.testsError.o7kjc-seed = {
    test-seed-wrong-message = {
      expr = throw "gen-dispatch-seed: the actual message";
      expectedError = {
        type = "ThrownError";
        msg = "gen-dispatch-seed: the EXPECTED message";
      };
    };
    test-seed-lix-nul = {
      expr = builtins.fromJSON "\"\\u0000\"";
      expectedError = {
        type = "Error";
        msg = "null bytes";
      };
    };
  };

  flake.testsError.door-checks = {
    test-mkrule-missing-required-field-message = {
      expr = mkRule { condition = { }; };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.mkRule: required field 'produce' is missing (required: 'condition', 'produce') (in prelude.checkRequired)";
      };
    };
    test-mkrule-unknown-option-message = {
      expr = mkRule {
        condition = { };
        produce = _id: _ctx: [ ];
        zzqran7f = 1;
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.mkRule: 'zzqran7f' is not an option of this door; the options are closed (accepted: 'condition', 'produce', 'nac', 'identity', 'priority', 'overrides', 'group', 'produces') (in prelude.checkOptions)";
      };
    };

    test-dispatch-missing-required-field-message = {
      expr = dispatch {
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
      expr = dispatch {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
        groupOrder = [ "g" ];
        zzqran7f = 1;
      };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.dispatch: 'zzqran7f' is not an option of this door; the options are closed (accepted: 'rules', 'id', 'context', 'match', 'classify', 'groupOrder', 'exclusive', 'extract', 'combine') (in prelude.checkOptions)";
      };
    };

    test-chain-missing-required-field-message = {
      expr = chain { };
      expectedError = {
        type = "ThrownError";
        msg = exactly "gen-dispatch.chain: required field 'extract' is missing (required: 'extract') (in prelude.checkRequired)";
      };
    };

    # LIVE CONTROL, same run, same output: a well-formed call on each door class answers rather
    # than throwing — the vacuity every cell above asserting a refusal invites, discharged here.
    test-control-mkrule-well-formed-call-answers = {
      expr =
        (mkRule {
          condition = { };
          produce = _id: _ctx: [ ];
        }).priority;
      expected = 0;
    };
    test-control-chain-well-formed-call-answers = {
      expr =
        let
          r = mkRule {
            condition = { };
            produce = _id: _ctx: [ ];
          };
        in
        (chain { extract = _actions: { }; } r r).identity;
      expected = null;
    };
  };
}
