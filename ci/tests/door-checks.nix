# THE CLOSED-DOOR CHECKS (den-hoag-7gp66 P1) — every published door catches its own violations.
#
# A native closed formal (`{ condition, produce, ... }:`) aborts UNCATCHABLY on an unknown or a
# missing argument — not even `builtins.tryEval` sees it, which is ADR-0025 item 1's named defect.
# Each of the three doors below now takes a bare positional formal and applies gen-prelude's
# shared `checkOptions`/`checkRequired` (0ac7b66) instead, so the same violations are NAMED and
# CATCHABLE.
#
# ★ THE DOOR CLASSES SPLIT THE FAMILY IN TWO. `mkRule` and `dispatch` are MIXED doors — required
# plus optional, `checkOptions` composed over `checkRequired` — and stay CLOSED on both axes until
# P2 splits the options off the record. `chain` is a RECORD door — one required field, `extract`,
# `checkRequired` only — and R5's stated price is that it is OPEN: an extra field is silently
# admitted, never refused.
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming each door (R6) live in `ci/tests-error.nix`'s `flake.testsError.door-checks`.
{ genDispatch, ... }:
let
  inherit (genDispatch) mkRule dispatch chain;

  # `success == false` pins catchability, not the message — the byte goldens are the message's own
  # test. Forced with `deepSeq null` so a lazily-returned attrset's unread check still runs.
  refusesCatchably = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  validRule = mkRule {
    condition = { };
    produce = _id: _ctx: [ ];
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

    # mkRule — MIXED class (checkOptions over checkRequired).
    test-mkrule-missing-required-field-refused-catchably = {
      expr = refusesCatchably (mkRule {
        condition = { };
      });
      expected = true;
    };
    test-mkrule-unknown-option-refused-catchably = {
      expr = refusesCatchably (mkRule {
        condition = { };
        produce = _id: _ctx: [ ];
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

    # dispatch — MIXED class.
    test-dispatch-missing-required-field-refused-catchably = {
      expr = refusesCatchably (dispatch {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
      });
      expected = true;
    };
    test-dispatch-unknown-option-refused-catchably = {
      expr = refusesCatchably (dispatch {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
        groupOrder = [ "g" ];
        zzqran7f = 1;
      });
      expected = true;
    };
    test-dispatch-valid-call-is-unchanged = {
      expr = dispatch {
        rules = [ ];
        id = null;
        context = { };
        match =
          _cond: _id: _ctx:
          true;
        classify = _a: "g";
        groupOrder = [ "g" ];
      };
      expected = {
        actions = { };
        orderedGroups = [ ];
        context = { };
      };
    };

    # chain — RECORD class (checkRequired only).
    test-chain-missing-required-field-refused-catchably = {
      expr = refusesCatchably (chain { });
      expected = true;
    };
    # R5's stated price: an extra field on a record door is ADMITTED, not refused.
    test-chain-extra-field-on-a-record-is-admitted = {
      expr = answers (chain {
        extract = _actions: { };
        zzqran7f = 1;
      });
      expected = true;
    };
    test-chain-valid-call-is-unchanged = {
      expr = (chain { extract = _actions: { }; } validRule validRule).identity;
      expected = null;
    };
  };
}
