# One-shot stratified dispatch: walk groups in the caller-supplied `groupOrder`,
# threading the context group->group via extract/combine. Within each group: match,
# resolve overrides (accumulated FORWARD across groups) + priority/exclusive, fire,
# classify-validate, group. Single/degenerate group + identity extract/combine
# reproduces the prior single-pass behavior exactly. Group ORDERING is not gen-dispatch's
# concern — the caller pre-orders (e.g. gen-graph's topological sort over an entry* DAG).
#
# `dispatch` is a pure function of (rules, context): a given context always yields the same
# actions. Iteration is the caller's — thread the domain state through repeated one-shot
# dispatch (gen-scope.circular) and read the actions off the fixpoint. Recomputing at the
# fixpoint makes the action set a function of the CONVERGED state, never the iteration path
# (a confluence guarantee), so dispatch keeps no cross-pass "already fired" bookkeeping.
{ prelude }:
let
  inherit (prelude)
    filter
    foldl'
    imap0
    sort
    unique
    ;

  # `dispatch { exclusive ?; extract ?; combine ?; } { rules; id; context; match; classify; groupOrder; }`
  # (P2, R7). The options are one closed set, first, checked when `dispatch opts` is formed. The six
  # operands stay ONE required-argument record (R7 (a)): they are three pairs of one role each — the
  # interpreters `match`/`classify` (both functions), the program `rules`/`groupOrder` (both lists) and
  # the subject `id`/`context` — and nothing orders the two members of a pair, so a positional order
  # would be an arbitrary one to remember. The record is a door too (open, as a record operand is), so
  # a missing operand is refused catchably, by name, when the record is applied. Both specs are bound
  # once, here; a call supplies only the bodies.
  dispatchOptions = prelude.door {
    name = "gen-dispatch.dispatch";
    next = dispatchOperandsSpec;
    optional = [
      "exclusive"
      "extract"
      "combine"
    ];
  };
  dispatchOperandsSpec = {
    name = "gen-dispatch.dispatch";
    required = [
      "rules"
      "id"
      "context"
      "match"
      "classify"
      "groupOrder"
    ];
    open = true;
    # (den-hoag-7gp66 P2 v1.2, premise 7) an option of dispatchOptions given here instead — e.g.
    # `dispatch { } (cfg // { exclusive = true; })` — is refused by name rather than silently
    # admitted and ignored: `exclusive`/`extract`/`combine` belong on the OPTIONS step, one
    # position earlier. Names the OUTER, already-built door (`dispatch`, not the unapplied
    # `dispatchOptions` constructor): `dispatch.__contract` is `dispatchOptions`'s own contract,
    # independent of `dispatch`'s body, so this is safe even though `dispatch`'s own definition
    # calls back into `dispatchOperands` (spec p2.3.2 v1.2).
    optionsStep = dispatch;
  };
  dispatchOperands = prelude.door dispatchOperandsSpec;
  dispatch = dispatchOptions (o: dispatchOperands (dispatchCore o));

  dispatchCore =
    o: args:
    let
      inherit (args)
        rules
        id
        context
        match
        classify
        groupOrder
        ;
      exclusive = o.exclusive or false;
      extract = o.extract or (_actions: { });
      combine = o.combine or (ctx: _delta: ctx);

      multiGroup = builtins.length groupOrder > 1;
      ruleName = r: if r.identity != null then r.identity else "anonymous";

      stepGroup =
        acc: groupName:
        let
          cand = filter (
            r:
            (
              if multiGroup then
                (
                  if r.group == null then
                    throw "gen-dispatch: rule \"${ruleName r}\" has no group but dispatch is stratified over [${builtins.concatStringsSep ", " groupOrder}]"
                  else
                    r.group == groupName
                )
              else
                true
            )
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
          # by declaration order, so the surviving set never depends on builtins.sort
          # stability or rule-list enumeration order. Surfaced by the ∆-Nets
          # analysis (equal-priority + `exclusive` ties were order-sensitive).
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
            # A rule that DECLARES its produced-kind family (`produces`) had its stratum discharged
            # at DEFINITION time (`deriveGroup` classified the declared kinds); dispatch HONORS that
            # declaration and skips the fire-and-classify inference below. `or null` keeps rules that
            # predate the field (e.g. `chain` results) on the classify path — byte-identical.
            declared = (r.produces or null) != null;
          }) filtered;

          validated = map (
            res:
            # Declared rules are trusted: their stratum is the declaration, not the classify of the
            # fired actions (mirrors gen-resolve trusting an equation's `stratum`). Undeclared rules
            # keep the classify-validation exactly as before — byte-identical when nothing declares.
            if res.declared then
              res
            else
              let
                actionGroups = unique (map classify res.actions);
              in
              if builtins.length actionGroups > 1 then
                throw "gen-dispatch: rule \"${ruleName res}\" produced actions in multiple groups: ${builtins.concatStringsSep ", " actionGroups}"
              else if multiGroup && res.actions != [ ] && builtins.head actionGroups != groupName then
                throw "gen-dispatch: rule \"${ruleName res}\" declared group \"${groupName}\" but produced \"${builtins.head actionGroups}\" actions"
              else
                res
          ) results;

          groupActions = builtins.concatLists (map (r: r.actions) validated);
        in
        {
          ctx = combine acc.ctx (extract {
            ${groupName} = groupActions;
          });
          grouped = acc.grouped // (if groupActions != [ ] then { ${groupName} = groupActions; } else { });
          present = acc.present ++ (if groupActions != [ ] then [ groupName ] else [ ]);
          overridden = overridden';
        };

      final = foldl' stepGroup {
        ctx = context;
        overridden = { };
        grouped = { };
        present = [ ];
      } groupOrder;
    in
    {
      actions = final.grouped;
      orderedGroups = final.present;
      context = final.ctx;
    };
in
{
  inherit dispatch;
}
