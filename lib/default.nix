# gen-dispatch is the relational dispatch STEP (guard->effect rules over ordered groups):
# mkRule/dispatch/NACs/conflict-resolution/restrict·override·chain/adapters.select. It owns
# RULE EVALUATION ONLY. The convergence LOOP belongs to gen-resolve (gen-scope.circular's
# Kleene ascent) and group ORDERING to gen-graph (a topological sort of before/after
# constraints); a caller iterates dispatch by threading pure domain state through repeated
# one-shot dispatch. Depends only on gen-prelude (pure, nixpkgs-lib-free): builtins
# re-exports + the vendored imap0/unique.
{ prelude }:
let
  rule = import ./core/rule.nix { inherit prelude; };
  actions = import ./core/actions.nix { inherit prelude; };
  dispatch' = import ./core/dispatch.nix { inherit prelude; };
  compose = import ./core/compose.nix { };
  selectAdapter = import ./adapters/select.nix { inherit prelude; };
in
{
  inherit (rule) mkRule fromFunction fromFunctionMatch;
  inherit (actions) mkActions;
  inherit (dispatch') dispatch;
  inherit (compose) restrict override chain;

  adapters = {
    select = selectAdapter;
  };
}
