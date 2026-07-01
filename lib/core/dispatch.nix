# One-shot stratified dispatch: walk phases in the caller-supplied `phaseOrder`,
# threading the context phase->phase via extract/combine. Within each phase: match,
# resolve overrides (accumulated FORWARD across phases) + priority/exclusive, fire,
# classify-validate, group. Single/degenerate phase + identity extract/combine
# reproduces the prior single-pass behavior exactly. Phase ORDERING is not gen-dispatch's
# concern — the caller pre-orders (e.g. gen-graph.phaseOrder over an entry* DAG).
{ prelude }:
let
  inherit (prelude)
    filter
    foldl'
    imap0
    sort
    unique
    ;

  dispatch =
    {
      rules,
      id,
      context,
      match,
      classify,
      phaseOrder,
      exclusive ? false,
      fired ? { },
      extract ? (_actions: { }),
      combine ? (ctx: _delta: ctx),
    }:
    let
      multiPhase = builtins.length phaseOrder > 1;
      ruleName = r: if r.identity != null then r.identity else "anonymous";

      stepPhase =
        acc: phaseName:
        let
          cand = filter (
            r:
            (
              if multiPhase then
                (
                  if r.phase == null then
                    throw "gen-dispatch: rule \"${ruleName r}\" has no phase but dispatch is stratified over [${builtins.concatStringsSep ", " phaseOrder}]"
                  else
                    r.phase == phaseName
                )
              else
                true
            )
            && (r.identity == null || !(acc.fired ? ${r.identity}))
            && (r.identity == null || !(acc.overridden ? ${r.identity}))
          ) rules;

          matched0 = filter (
            r:
            let
              nacPasses = r.nac == null || !(match r.nac id acc.ctx);
              condPasses = match r.condition id acc.ctx;
            in
            nacPasses && condPasses
          ) cand;

          overridden' = foldl' (
            o: r: foldl' (o': oid: o' // { ${oid} = true; }) o r.overrides
          ) acc.overridden (filter (r: r.overrides != [ ]) matched0);

          matched = filter (r: r.identity == null || !(overridden' ? ${r.identity})) matched0;

          # Total-order sort: priority descending, ties broken deterministically
          # by declaration order, so the fired set never depends on builtins.sort
          # stability or rule-list enumeration order. Surfaced by the ∆-Nets
          # analysis (equal-priority + `exclusive` ties were order-sensitive); see
          # papers/den-architecture/gen-specs/DELTA-NETS-FOLLOWUPS.md item E1.
          sorted = map (x: x.r) (
            sort (a: b: if a.r.priority != b.r.priority then a.r.priority > b.r.priority else a.i < b.i) (
              imap0 (i: r: { inherit i r; }) matched
            )
          );

          filtered =
            if !exclusive || sorted == [ ] then
              sorted
            else
              let
                topPriority = (builtins.head sorted).priority;
              in
              filter (r: r.priority == topPriority) sorted;

          results = map (r: {
            inherit (r) identity;
            actions = r.produce id acc.ctx;
          }) filtered;

          validated = map (
            res:
            let
              actionPhases = unique (map classify res.actions);
            in
            if builtins.length actionPhases > 1 then
              throw "gen-dispatch: rule \"${ruleName res}\" produced actions in multiple phases: ${builtins.concatStringsSep ", " actionPhases}"
            else if multiPhase && res.actions != [ ] && builtins.head actionPhases != phaseName then
              throw "gen-dispatch: rule \"${ruleName res}\" declared phase \"${phaseName}\" but produced \"${builtins.head actionPhases}\" actions"
            else
              res
          ) results;

          phaseActions = builtins.concatLists (map (r: r.actions) validated);

          newFired = foldl' (
            f: r: if r.identity != null then f // { ${r.identity} = true; } else f
          ) acc.fired validated;
        in
        {
          ctx = combine acc.ctx (extract {
            ${phaseName} = phaseActions;
          });
          fired = newFired;
          overridden = overridden';
          grouped = acc.grouped // (if phaseActions != [ ] then { ${phaseName} = phaseActions; } else { });
          present = acc.present ++ (if phaseActions != [ ] then [ phaseName ] else [ ]);
        };

      final = foldl' stepPhase {
        ctx = context;
        inherit fired;
        overridden = { };
        grouped = { };
        present = [ ];
      } phaseOrder;
    in
    {
      actions = final.grouped;
      orderedPhases = final.present;
      context = final.ctx;
      fired = final.fired;
    };
in
{
  inherit dispatch;
}
