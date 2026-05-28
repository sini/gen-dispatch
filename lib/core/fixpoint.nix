# Fixpoint convergence: iteratively dispatch rules until context stabilizes.
{ lib, dispatchFn }:
let
  fixpoint =
    {
      rules,
      context,
      match,
      classify,
      phases,
      extract,
      combine,
      eq,
      id ? null,
      exclusive ? false,
      maxIter ? 100,
    }:
    let
      go =
        iteration: ctx: fired: accActions:
        let
          result = dispatchFn {
            inherit
              rules
              match
              classify
              phases
              exclusive
              fired
              id
              ;
            context = ctx;
          };
          mergedActions = lib.foldl' (
            acc: phase: acc // { ${phase} = (acc.${phase} or [ ]) ++ result.actions.${phase}; }
          ) accActions (builtins.attrNames result.actions);
          extracted = extract result.actions;
          newCtx = combine ctx extracted;
        in
        if eq ctx newCtx then
          {
            actions = mergedActions;
            context = newCtx;
            iterations = iteration;
            fired = result.fired;
          }
        else if iteration >= maxIter then
          throw "gen-derive: fixpoint did not converge after ${toString maxIter} iterations"
        else
          go (iteration + 1) newCtx result.fired mergedActions;
    in
    go 1 context { } { };
in
{
  inherit fixpoint;
}
