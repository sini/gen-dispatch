# Fixpoint convergence: iteratively run a stratified dispatch pass until the
# context stabilizes. Intra-pass phase threading lives in dispatch; fixpoint
# only owns inter-pass convergence + ordered action accumulation.
{ prelude, dispatchFn }:
let
  inherit (prelude) foldl';

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
              extract
              combine
              ;
            context = ctx;
          };
          mergedActions = foldl' (
            acc: phase: acc // { ${phase} = (acc.${phase} or [ ]) ++ result.actions.${phase}; }
          ) accActions result.orderedPhases;
        in
        if eq ctx result.context then
          {
            actions = mergedActions;
            inherit (result) orderedPhases context;
            iterations = iteration;
            fired = result.fired;
          }
        else if iteration >= maxIter then
          throw "gen-derive: fixpoint did not converge after ${toString maxIter} iterations"
        else
          go (iteration + 1) result.context result.fired mergedActions;
    in
    go 1 context { } { };
in
{
  inherit fixpoint;
}
