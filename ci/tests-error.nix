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
{ genDispatch, ... }:
let
  inherit (genDispatch) mkRule deriveGroup;
  fx = genDispatch.mkActions {
    structural = [ "spawn" ];
    resolution = [
      "edge"
      "drop"
    ];
  };
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
}
