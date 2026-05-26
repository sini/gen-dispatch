# Inline DAG entry constructors over lib.toposort.
# Pattern from home-manager's dag library (generalized strings-with-deps).
{ lib }:
let
  inherit (lib) filterAttrs mapAttrs toposort;

  entryBetween = before: after: data: { inherit data before after; };
  entryAnywhere = entryBetween [] [];
  entryAfter = entryBetween [];
  entryBefore = before: entryBetween before [];

  topoSort = dag:
    let
      dagBefore = name:
        builtins.attrNames (filterAttrs (_n: v: builtins.elem name v.before) dag);
      normalized = mapAttrs (n: v: {
        name = n;
        inherit (v) data;
        after = v.after ++ dagBefore n;
      }) dag;
      before = a: b: builtins.elem a.name b.after;
      sorted = toposort before (builtins.attrValues normalized);
    in
    if sorted ? result then
      { result = map (v: { inherit (v) name data; }) sorted.result; }
    else
      sorted;
in
{
  inherit entryBetween entryAnywhere entryAfter entryBefore topoSort;
}
