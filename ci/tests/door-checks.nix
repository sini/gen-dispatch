# THE DOOR CHECKS (den-hoag-7gp66 P1, reshaped by P2) — every published door catches its own
# violations.
#
# A native closed formal (`{ condition, produce, ... }:`) aborts UNCATCHABLY on an unknown or a
# missing argument — not even `builtins.tryEval` sees it, which is ADR-0025 item 1's named defect.
# The doors below are built through gen-prelude's `door`, so the same violations are NAMED and
# CATCHABLE.
#
# ★ AFTER P2 THE FAMILY SPLITS THREE WAYS. The OPTIONS of `mkRule` and `dispatch` are a closed set
# of their own, first in the call, so an unknown option is refused. `dispatch`'s six operands and
# `override`'s two rules are RECORD doors — required fields, R5's stated price that the record is
# OPEN, so an extra field is admitted, never refused. `mkRule`'s `condition`/`produce` and `chain`'s
# `extract` are POSITIONAL: their arity is structural, and they carry no field check.
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming each door (R6) live in `ci/tests-error.nix`'s `flake.testsError.door-checks`.
{ genDispatch, ... }:
let
  inherit (genDispatch)
    mkRule
    dispatch
    chain
    override
    ;

  # `success == false` pins catchability, not the message — the byte goldens are the message's own
  # test. Forced with `deepSeq null` so a lazily-returned attrset's unread check still runs.
  refusesCatchably = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  validRule = mkRule { } { } (_id: _ctx: [ ]);
  operands = {
    rules = [ ];
    id = null;
    context = { };
    match =
      _cond: _id: _ctx:
      true;
    classify = _a: "g";
    groupOrder = [ "g" ];
  };
in
{
  flake.tests.door-checks = {
    # ★ LIVE CONTROL FOR THE WHOLE SUITE, first: `tryEval` catches an ORDINARY throw, and a
    # non-throwing value answers. Without this, every `refusesCatchably` cell below is equally
    # consistent with a broken helper that reads `false` no matter what it is handed.
    test-control-tryeval-catches-an-ordinary-throw = {
      expr = refusesCatchably (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-tryeval-answers-a-non-throwing-value = {
      expr = answers 1;
      expected = true;
    };

    # mkRule — options door, then positional `condition` and `produce`.
    test-mkrule-unknown-option-refused-catchably = {
      expr = refusesCatchably (mkRule {
        zzqran7f = 1;
      });
      expected = true;
    };
    test-mkrule-valid-call-is-unchanged = {
      expr = {
        inherit (validRule)
          condition
          priority
          overrides
          group
          produces
          ;
        hasProduce = builtins.isFunction validRule.produce;
      };
      expected = {
        condition = { };
        priority = 0;
        overrides = [ ];
        group = null;
        produces = null;
        hasProduce = true;
      };
    };
    # G3: a non-default option reaches the partially applied door, and it is the option's value, not
    # the default's.
    test-mkrule-partial-application-carries-a-non-default-option = {
      expr =
        let
          f0 = mkRule { };
          f1 = mkRule { priority = 5; };
        in
        {
          agrees =
            (f1 { } (_id: _ctx: [ ])).priority == (mkRule { priority = 5; } { } (_id: _ctx: [ ])).priority;
          differs = (f1 { } (_id: _ctx: [ ])).priority != (f0 { } (_id: _ctx: [ ])).priority;
        };
      expected = {
        agrees = true;
        differs = true;
      };
    };
    # D3: the options are published as data, and the map is the native formals the door stands for.
    test-mkrule-options-published-as-data = {
      expr =
        mkRule.__functionArgs == builtins.functionArgs (
          {
            nac ? null,
            identity ? null,
            priority ? 0,
            overrides ? [ ],
            group ? null,
            produces ? null,
          }:
          null
        );
      expected = true;
    };

    # dispatch — options door, then one open record of operands (R7 (a)).
    test-dispatch-missing-operand-refused-catchably = {
      expr = refusesCatchably (dispatch { } (builtins.removeAttrs operands [ "groupOrder" ]));
      expected = true;
    };
    test-dispatch-unknown-option-refused-catchably = {
      expr = refusesCatchably (dispatch {
        zzqran7f = 1;
      });
      expected = true;
    };
    # R5's stated price: an extra field on a record door is ADMITTED, not refused.
    test-dispatch-extra-field-on-the-operand-record-is-admitted = {
      expr = answers (dispatch { } (operands // { zzqran7f = 1; }));
      expected = true;
    };
    test-dispatch-valid-call-is-unchanged = {
      expr = dispatch { } operands;
      expected = {
        actions = { };
        orderedGroups = [ ];
        context = { };
      };
    };
    # G3: a non-default `combine` reaches the partially applied door.
    test-dispatch-partial-application-carries-a-non-default-option = {
      expr =
        let
          mark = ctx: _delta: ctx // { marked = true; };
          f0 = dispatch { };
          f1 = dispatch { combine = mark; };
        in
        {
          agrees = (f1 operands).context == (dispatch { combine = mark; } operands).context;
          differs = (f1 operands).context != (f0 operands).context;
        };
      expected = {
        agrees = true;
        differs = true;
      };
    };
    test-dispatch-contracts-published-as-data = {
      expr = [
        (
          dispatch.__functionArgs == builtins.functionArgs (
            {
              exclusive ? false,
              extract ? null,
              combine ? null,
            }:
            null
          )
        )
        dispatch.__contract.optional
        (
          (dispatch { }).__functionArgs == builtins.functionArgs (
            {
              rules,
              id,
              context,
              match,
              classify,
              groupOrder,
              ...
            }:
            null
          )
        )
      ];
      expected = [
        true
        [
          "exclusive"
          "extract"
          "combine"
        ]
        true
      ];
    };

    # override — one open record of two rules (R7 (b)).
    test-override-missing-rule-refused-catchably = {
      expr = refusesCatchably (override {
        original = validRule;
      });
      expected = true;
    };
    test-override-publishes-its-fields = {
      expr = override.__functionArgs == builtins.functionArgs ({ original, replacement, ... }: null);
      expected = true;
    };

    # chain — positional, `extract` first.
    test-chain-valid-call-is-unchanged = {
      expr = (chain (_actions: { }) validRule validRule).identity;
      expected = null;
    };
  };
}
