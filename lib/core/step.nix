# The dispatch STEP as a convergence-loop step function — the non-loop remnant of the
# old fixpoint.nix (its per-pass action-merge fold). Driver-agnostic: it owns NO
# iteration or convergence (that is the caller's loop, e.g. gen-scope.circular's Kleene
# ascent). Prelude-only, so gen-derive stays nixpkgs-lib-free.
#
# `dispatchStep { dispatch } cfg` yields a `self: id: prev -> next` step whose shape
# (self:id:prev) matches gen-scope.circular's `f: self: id`. The circular VALUE it
# threads is `{ context; fired; accActions; orderedPhases }`: `fired` carried across
# passes (once-per-identity dedup), `accActions` accumulated with the exact fold the old
# fixpoint used. Pair it with `dispatchInit ctx` for the seed. Proven byte-identical to
# the old `fixpoint` on the den path — gen-resolve/spike/gen-derive-loop-step/spike.nix.
{ prelude }:
let
  inherit (prelude) foldl';

  # cfg = { rules, match, classify, phaseOrder, extract, combine, id, exclusive ? }
  dispatchStep =
    { dispatch }:
    cfg: _self: _id: prev:
    let
      r = dispatch (
        cfg
        // {
          context = prev.context;
          inherit (prev) fired;
        }
      );
      accActions = foldl' (
        acc: p: acc // { ${p} = (acc.${p} or [ ]) ++ r.actions.${p}; }
      ) prev.accActions r.orderedPhases;
    in
    {
      inherit (r) context fired orderedPhases;
      inherit accActions;
    };

  dispatchInit = context: {
    inherit context;
    fired = { };
    accActions = { };
    orderedPhases = [ ];
  };
in
{
  inherit dispatchStep dispatchInit;
}
