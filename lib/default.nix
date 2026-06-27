# gen-derive depends only on gen-prelude (pure, nixpkgs-lib-free): builtins via prelude
# re-exports + the vendored filterAttrs/imap0/unique/toposort. The former gen-algebra
# dependency was dead (rule.nix never referenced it) and has been dropped.
{ prelude }:
let
  dag = import ./core/dag.nix { inherit prelude; };
  rule = import ./core/rule.nix { inherit prelude; };
  actions = import ./core/actions.nix { inherit prelude; };
  dispatch' = import ./core/dispatch.nix { inherit prelude dag; };
  fixpoint' = import ./core/fixpoint.nix {
    inherit prelude;
    dispatchFn = dispatch'.dispatch;
  };
  compose = import ./core/compose.nix { };
  selectAdapter = import ./adapters/select.nix { inherit prelude; };
in
{
  inherit (dag)
    entryBetween
    entryAnywhere
    entryAfter
    entryBefore
    topoSort
    ;
  inherit (rule) mkRule fromFunction fromFunctionMatch;
  inherit (actions) mkActions;
  inherit (dispatch') dispatch;
  inherit (fixpoint') fixpoint;
  inherit (compose) restrict override chain;

  adapters = {
    select = selectAdapter;
  };
}
