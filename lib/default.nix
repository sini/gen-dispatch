{ lib, genPure }:
let
  dag = import ./core/dag.nix { inherit lib; };
  rule = import ./core/rule.nix { inherit lib genPure; };
  actions = import ./core/actions.nix { inherit lib; };
  dispatch' = import ./core/dispatch.nix { inherit lib dag; };
  fixpoint' = import ./core/fixpoint.nix { inherit lib; dispatchFn = dispatch'.dispatch; };
  compose = import ./core/compose.nix { inherit lib; };
  selectAdapter = import ./adapters/select.nix { inherit lib; };
in
{
  inherit (dag) entryBetween entryAnywhere entryAfter entryBefore topoSort;
  inherit (rule) mkRule fromFunction fromFunctionMatch;
  inherit (actions) mkActions;
  inherit (dispatch') dispatch;
  inherit (fixpoint') fixpoint;
  inherit (compose) restrict override chain;

  adapters = {
    select = selectAdapter;
  };
}
