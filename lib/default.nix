# gen-derive is the relational dispatch STEP (guard->effect rules over ordered phases):
# mkRule/dispatch/NACs/conflict-resolution/restrict·override·chain/adapters.select. The
# convergence LOOP moved to gen-resolve (gen-scope.circular's Kleene ascent) and phase
# ORDERING to gen-graph (phaseOrder) — see the equivalence proof in
# gen-resolve/spike/gen-derive-loop-step/ and the plan in
# gen-specs/gen-derive/2026-07-01-gen-derive-refactor-plan.md. Depends only on gen-prelude
# (pure, nixpkgs-lib-free): builtins re-exports + the vendored imap0/unique.
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
