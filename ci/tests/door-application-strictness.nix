# THE DOOR CHECKS FIRE AT APPLICATION, NOT ONLY BEHIND A LATER FIELD READ (den-hoag-7gp66 P1
# lazy-doors fix; P2's options-first shape).
#
# `door-checks.nix` proves the doors' violations are CATCHABLE, but does so with `deepSeq`, which
# forces straight through to the guard whichever field it hangs off. This file uses the narrower
# predicate: `seq` alone, to WHNF of the door's OWN return, reading NO field at all — the shape of a
# defensive `builtins.seq (door args) rest` a caller writes to gate on validity before touching any
# output.
#
# MEASURED (den-hoag-7gp66 P1 strictness sweep, gen-memo eed0685's defect class — a check that sits
# behind a later read is a check a caller who does not make that read never runs): `mkRule` and
# `dispatch` once returned a bare attrset literal, whose own WHNF forced none of its fields. They are
# now built through gen-prelude's `door`, which forces its check at the application's own WHNF, so
# an unknown option is refused when `door opts` is formed, before any operand (P2, G4), and a
# missing operand when the record is applied.
{ genDispatch, ... }:
let
  inherit (genDispatch) mkRule dispatch override;

  # `seq`, not `deepSeq`: WHNF of the door's own return, no field read.
  refusesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answersAtApplication = e: (builtins.tryEval (builtins.seq e null)).success;

  validRule = mkRule { } { } (_id: _ctx: [ ]);
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

    # mkRule — the options are refused at `mkRule opts`, with no operand applied.
    test-mkrule-unknown-option-refused-at-application = {
      expr = refusesAtApplication (mkRule {
        zzqran7f = 1;
      });
      expected = true;
    };

    # dispatch — the options at `dispatch opts`; a missing operand at the record's application.
    test-dispatch-unknown-option-refused-at-application = {
      expr = refusesAtApplication (dispatch {
        zzqran7f = 1;
      });
      expected = true;
    };
    test-dispatch-missing-operand-refused-at-application = {
      expr = refusesAtApplication (
        dispatch { } {
          rules = [ ];
          id = null;
          context = { };
          match =
            _cond: _id: _ctx:
            true;
          classify = _a: "g";
        }
      );
      expected = true;
    };

    # override — a missing rule at the record's application.
    test-override-missing-rule-refused-at-application = {
      expr = refusesAtApplication (override {
        original = validRule;
      });
      expected = true;
    };
    test-override-extra-field-is-admitted-at-application = {
      expr = answersAtApplication (override {
        original = validRule // {
          identity = "r";
        };
        replacement = validRule;
        zzqran7f = 1;
      });
      expected = true;
    };
  };
}
