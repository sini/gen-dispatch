# One-shot dispatch: match rules, resolve overrides + priority, group by phase.
{ lib, dag }:
let
  inherit (lib) filter foldl' sort unique;

  dispatch =
    {
      rules,
      id,
      context,
      match,
      classify,
      phases,
      exclusive ? false,
      fired ? { },
    }:
    let
      # Phase ordering (validated, not used for grouping but available for consumers)
      phaseOrder = dag.topoSort phases;
      phaseList =
        if phaseOrder ? result then
          map (e: e.name) phaseOrder.result
        else
          throw "gen-derive: cycle in phase DAG";

      # Step 1: match rules (NAC + condition, skip already-fired)
      candidateMatched = filter (
        r:
        let
          nacPasses = r.nac == null || !(match r.nac id context);
          condPasses = match r.condition id context;
          notFired = r.identity == null || !(fired ? ${r.identity});
        in
        nacPasses && condPasses && notFired
      ) rules;

      # Step 2: collect overridden identities from matched rules only
      overriddenIds = foldl' (
        acc: r: foldl' (acc': oid: acc' // { ${oid} = true; }) acc r.overrides
      ) { } (filter (r: r.overrides != [ ]) candidateMatched);

      # Step 3: remove overridden rules from matched set
      matched = filter (r: r.identity == null || !(overriddenIds ? ${r.identity})) candidateMatched;

      # Step 4: sort by priority (descending)
      sorted = sort (a: b: a.priority > b.priority) matched;

      # Step 5: exclusive mode keeps only highest priority group
      filtered =
        if !exclusive || sorted == [ ] then
          sorted
        else
          let
            topPriority = (builtins.head sorted).priority;
          in
          filter (r: r.priority == topPriority) sorted;

      # Step 6: fire rules and collect actions
      results = map (r: {
        inherit (r) identity;
        actions = r.produce id context;
      }) filtered;

      # Step 7: validate single-phase-per-rule
      validated = map (
        res:
        let
          actionPhases = unique (map classify res.actions);
        in
        if builtins.length actionPhases > 1 then
          throw "gen-derive: rule \"${
            if res.identity != null then res.identity else "anonymous"
          }\" produced actions in multiple phases: ${builtins.concatStringsSep ", " actionPhases}"
        else
          res
      ) results;

      # Step 8: group actions by phase
      allActions = builtins.concatLists (map (r: r.actions) validated);
      grouped = foldl' (
        acc: action:
        let
          phase = classify action;
        in
        acc // { ${phase} = (acc.${phase} or [ ]) ++ [ action ]; }
      ) { } allActions;

      # Step 9: track fired identities (skip anonymous)
      newFired = foldl' (
        acc: r: if r.identity != null then acc // { ${r.identity} = true; } else acc
      ) fired validated;
    in
    {
      actions = grouped;
      fired = newFired;
    };
in
{
  inherit dispatch;
}
