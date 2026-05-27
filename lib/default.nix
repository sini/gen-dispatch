{
  inputs ? { },
  lib,
  genAlgebra ? null,
}:
let
  # No-flakes import: resolve gen-algebra from CI flake.lock
  lock = builtins.fromJSON (builtins.readFile ../../ci/flake.lock);
  inherit (lock.nodes.gen-algebra) locked;
  genAlgebraSrc = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.zip";
    sha256 = locked.narHash;
  };
  resolvedGenAlgebra =
    if genAlgebra != null then genAlgebra else (inputs.gen-algebra or (import genAlgebraSrc { })).pure;

  dag = import ./core/dag.nix { inherit lib; };
  rule = import ./core/rule.nix {
    inherit lib;
    genAlgebra = resolvedGenAlgebra;
  };
  actions = import ./core/actions.nix { inherit lib; };
  dispatch' = import ./core/dispatch.nix { inherit lib dag; };
  fixpoint' = import ./core/fixpoint.nix {
    inherit lib;
    dispatchFn = dispatch'.dispatch;
  };
  compose = import ./core/compose.nix { inherit lib; };
  selectAdapter = import ./adapters/select.nix { inherit lib; };
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
