# gen-dispatch is the relational dispatch STEP (guard->effect rules over ordered phases):
# mkRule/dispatch/NACs/conflict-resolution/restrict·override·chain/adapters.select. The
# convergence LOOP moved to gen-resolve (gen-scope.circular's Kleene ascent) and phase
# ORDERING to gen-graph (phaseOrder); the loop⊥step split is proven byte-identical by the
# equivalence spike. Depends only on gen-prelude (pure, nixpkgs-lib-free): builtins
# re-exports + the vendored imap0/unique.
{ prelude }:
let
  rule = import ./core/rule.nix { inherit prelude; };
  actions = import ./core/actions.nix { inherit prelude; };
  dispatch' = import ./core/dispatch.nix { inherit prelude; };
  step = import ./core/step.nix { inherit prelude; };
  compose = import ./core/compose.nix { };
  selectAdapter = import ./adapters/select.nix { inherit prelude; };
in
{
  inherit (rule) mkRule fromFunction fromFunctionMatch;
  inherit (actions) mkActions;
  inherit (dispatch') dispatch;
  inherit (step) dispatchStep dispatchInit;
  inherit (compose) restrict override chain;

  adapters = {
    select = selectAdapter;
  };
}
