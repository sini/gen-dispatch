# THE DOOR CHECKS FIRE AT APPLICATION, NOT ONLY BEHIND A LATER FIELD READ (den-hoag-7gp66 P1
# lazy-doors fix).
#
# `door-checks.nix` proves the three doors' checkOptions/checkRequired violations are CATCHABLE,
# but does so with `deepSeq` — and its own comment already names the gap that leaves open: a bare
# `(mkRule badArgs).condition` would never touch a violation on a field that read does not force.
# This file closes that gap with a narrower, harder predicate: `seq` alone, to WHNF of the door's
# OWN return, reading NO field at all — the shape of a defensive `builtins.seq (door args) rest` a
# caller writes to gate on validity before touching any output.
#
# MEASURED (den-hoag-7gp66 P1 strictness sweep, gen-memo eed0685's defect class — a check that sits
# behind a later read is a check a caller who does not make that read never runs): `mkRule` and
# `dispatch` both returned a bare attrset literal, whose own WHNF forces none of its fields, so a
# bad record sailed through the door's own application and was admitted until a caller forced one
# of the output fields. Fixed by threading `builtins.seq checked` through each return — the same
# idiom gen-settings' `resolveOne`/`resolveAll`/`injectAspectSettings` (0474486) use. `chain` was
# already strict (`builtins.seq extract (...)` forces `extract` — hence `checked` — before the
# curried lambda is returned); its cells below are the pin.
{ genDispatch, ... }:
let
  inherit (genDispatch) mkRule dispatch chain;

  # `seq`, not `deepSeq`: WHNF of the door's own return, no field read — the strictly narrower
  # predicate `door-checks.nix`'s `deepSeq`-based `refusesCatchably` cannot discriminate, since
  # `deepSeq` forces straight through to the same guard whichever field it hangs off.
  refusesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answersAtApplication = e: (builtins.tryEval (builtins.seq e null)).success;

  validRule = mkRule {
    condition = { };
    produce = _id: _ctx: [ ];
  };
in
{
  flake.tests.door-application-strictness = {
    # ★ LIVE CONTROL FOR THE WHOLE SUITE, first: `tryEval`+`seq` catches an ordinary throw, and a
    # non-throwing value answers. Without this, every `refusesAtApplication` cell below is equally
    # consistent with a predicate that reads `false` no matter what it is handed.
    test-control-tryeval-seq-catches-an-ordinary-throw = {
      expr = refusesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-tryeval-seq-answers-a-non-throwing-value = {
      expr = answersAtApplication 1;
      expected = true;
    };

    # mkRule — FIXED: was a bare attrset literal; now `builtins.seq checked { … }`.
    test-mkrule-missing-required-field-refused-at-application = {
      expr = refusesAtApplication (mkRule {
        condition = { };
      });
      expected = true;
    };
    test-mkrule-unknown-option-refused-at-application = {
      expr = refusesAtApplication (mkRule {
        condition = { };
        produce = _id: _ctx: [ ];
        zzqran7f = 1;
      });
      expected = true;
    };

    # dispatch — FIXED: was a bare attrset literal; now `builtins.seq checked { … }`.
    test-dispatch-missing-required-field-refused-at-application = {
      expr = refusesAtApplication (dispatch {
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
    test-dispatch-unknown-option-refused-at-application = {
      expr = refusesAtApplication (dispatch {
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

    # chain — already strict (`builtins.seq extract (…)` forces `extract` — hence `checked` — before
    # the curried lambda is returned). Pinned, not fixed. Curried, spec-only application: only the
    # leading record argument is applied, per the sweep's own methodology.
    test-chain-missing-required-field-refused-at-application = {
      expr = refusesAtApplication (chain { });
      expected = true;
    };
    # R5's stated price is unchanged: an extra field on a record door is still admitted, and is
    # admitted at application too — `checkRequired` never looks at it either way.
    test-chain-extra-field-on-a-record-is-admitted-at-application = {
      expr = answersAtApplication (chain {
        extract = _actions: { };
        zzqran7f = 1;
      });
      expected = true;
    };
  };
}
