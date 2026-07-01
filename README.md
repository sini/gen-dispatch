# gen-dispatch

[![CI](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Relational rule dispatch — the guard→effect **dispatch step**, implemented as a pure Nix library.

gen-dispatch is a **production rule system** (Forgy, 1982) with **stratified phases** (Arntzenius & Krishnaswami, 2016) and **algebraic graph rewriting** vocabulary (Ehrig et al., 2006). Given rules (condition + action producer), a position, and a context, gen-dispatch answers: "which rules fire here, and what actions do they produce?" It owns dispatch, conflict resolution, and rule dedup over a caller-supplied phase order — all rules in phase N complete before phase N+1 begins, with context threaded between phases. Actions are opaque -- the vocabulary belongs to the consumer.

gen-dispatch is one dispatch **step**. Two neighbouring concerns are deliberately *not* here: the convergence **loop** that iterates dispatch to a fixpoint (a circular attribute's Kleene ascent) belongs to [gen-resolve](https://github.com/sini/gen-resolve) / `gen-scope.circular`, and phase **ordering** (turning `before`/`after` constraints into a linear order) belongs to [gen-graph](https://github.com/sini/gen-graph) (`phaseOrder`). The loop⊥step split is proven byte-identical in `gen-resolve/spike/gen-derive-loop-step/`.

gen-dispatch is generic. It has no knowledge of NixOS, aspects, policies, or system configuration. It provides dispatch machinery; consumers define what to compute.

## Table of Contents

- [Core Insight](#core-insight)
- [Terminology](#terminology)
- [Gen Ecosystem](#gen-ecosystem)
- [Usage](#usage)
- [Example](#example)
- [Two-Tier Architecture](#two-tier-architecture)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Core Insight

The hard part of rule dispatch is the generic guard→effect protocol: rules declare what they need, and the engine handles when and how they fire (match, NAC, priority, override, phase threading). Hand-rolling this caused PRs 408-437 in den (all context-threading regressions). gen-dispatch extracts the protocol as one dispatch **step**. Wrapping repeated steps into a fixpoint — extract feedback, widen context, re-dispatch until stable — is a *separable* concern owned by gen-resolve (`gen-scope.circular`'s Kleene ascent); pair a step with a loop via `dispatchStep` / `dispatchInit`.

## Terminology

| Term | Definition | Source |
|------|-----------|--------|
| Rule | Guarded transformation unit: condition + action producer + identity | Ehrig 2006; Forgy 1982 |
| Condition | Predicate determining when a rule fires | Forgy 1982 (RETE LHS) |
| Action | Opaque tagged value produced when a rule fires | Forgy 1982 (RETE RHS) |
| Phase | Named dispatch group with DAG ordering | Arntzenius 2016 (stratification) |
| Match | Testing a condition against a position | Ehrig 2006 (match morphism) |
| Dispatch step | One guard→effect pass over ordered phases (the unit a convergence loop iterates) | Forgy 1982; Arntzenius 2016 |
| NAC | Negative application condition -- pattern that must NOT match | Ehrig 2006 |

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (search, record, identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect types (traits, classification, dispatch) |
| [gen-graph](https://github.com/sini/gen-graph) | Graph queries (combinators, traversals, fixpoint) |
| [gen-scope](https://github.com/sini/gen-scope) | Scope graphs (construction, evaluation, resolution) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject args into NixOS modules) |
| [gen-dispatch](https://github.com/sini/gen-dispatch) | Rule dispatch STEP (stratified phases, conflict resolution) |

## Usage

```nix
# flake.nix
{
  inputs.gen-dispatch.url = "github:sini/gen-dispatch";
  outputs = { gen-dispatch, ... }:
    let derive = gen-dispatch.lib;      # takes only gen-prelude, transitively
    in { /* ... */ };
}

# Or without flakes (standalone shim pins gen-prelude from the lock):
let derive = import ./gen-dispatch;
in { /* ... */ }
```

## Example

Policy-like rules that enrich context and produce typed actions across stratified phases.
Ordering comes from `gen-graph.phaseOrder`; a single `dispatch` threads context between
phases in that order:

```nix
let
  derive = gen-dispatch.lib;
  graph  = gen-graph.lib;

  # Define action vocabulary -- gen-dispatch classifies but doesn't interpret
  fx = derive.mkActions {
    structural = [ "spawn" "enrich" ];
    resolution = [ "edge" ];
  };

  rules = [
    # Function signature IS the condition (canTake pattern)
    (derive.fromFunction ({ host, ... }: [
      (fx.enrich { key = "isNixos"; value = true; })
      (fx.spawn { kind = "user"; })
    ]))

    # This rule fires only after enrichment adds "isNixos" to context
    (derive.mkRule {
      condition = { host = false; isNixos = false; };
      produce = _id: _ctx: [ (fx.edge { target = "logging"; }) ];
      identity = "nixos-edges";
    })
  ];

  cfg = {
    inherit rules;
    id = null;
    match = derive.fromFunctionMatch;
    classify = fx.classify;
    # phase ORDERING is gen-graph's job
    phaseOrder = graph.phaseOrder {
      structural = graph.entryAnywhere;
      resolution = graph.entryAfter [ "structural" ];
    };
    extract = actions:
      lib.foldl' (acc: a:
        if a.__action == "enrich" then acc // { ${a.key} = a.value; } else acc
      ) {} (actions.structural or []);
    combine = ctx: ext: ctx // ext;
  };

  # One pass: the enrich→resolution cascade completes because context threads forward.
  result = derive.dispatch (cfg // { context = { host = { name = "igloo"; }; }; });
in
  result.actions   # { structural = [ enrich, spawn ]; resolution = [ edge ]; }
```

**When you need a convergence loop** (genuinely cyclic rules that must iterate to a
fixpoint), the LOOP is gen-resolve's, not gen-dispatch's — wrap the step with
`gen-scope.circular`:

```nix
let
  scope = gen-scope.lib;
  step  = derive.dispatchStep { inherit (derive) dispatch; } cfg;   # self:id:prev -> next
in
  (scope.circular {
    init = derive.dispatchInit { host = { name = "igloo"; }; };     # { context; fired; accActions; ... }
    eq   = a: b: builtins.attrNames a.context == builtins.attrNames b.context;
  } step) {} null                                                    # -> { context; fired; accActions; ... }
```

`dispatchStep` threads `fired` (once-per-identity dedup) and accumulates actions across
passes exactly as the old `fixpoint` did; `gen-scope.circular` drives the Kleene ascent.
This composition is proven byte-identical to the retired `fixpoint` in
`gen-resolve/spike/gen-derive-loop-step/`.

## Two-Tier Architecture

gen-dispatch follows gen-algebra's pure/lib two-tier model:

- **Core tier** -- depends on gen-algebra pure tier only. Conditions are opaque; caller provides `match : condition -> id -> ctx -> bool`.
- **Adapter tier** -- imports gen-select. Bridges gen-select selectors into gen-dispatch conditions with `mkMatch` and `selectorSpecificity`.

Consumers without gen-select can use gen-dispatch with custom match functions. Consumers with gen-select get selector pattern matching and CSS-like specificity for conflict resolution.

## API Reference

### `dispatch`

```nix
dispatch {
  rules;              # [ rule ]
  id;                 # current position
  context;            # caller-defined context
  match;              # condition -> id -> ctx -> bool
  classify;           # action -> phase name
  phaseOrder;         # [ phaseName ] — pre-ordered (e.g. gen-graph.phaseOrder); dispatch does NOT sort
  exclusive ? false;  # only highest-priority group fires
  fired ? {};         # pre-seeded fired identity set
  extract ? (_: {});       # { phase = [action]; } -> ctx delta (per-phase threading; default no-op)
  combine ? (ctx: _: ctx); # ctx -> delta -> ctx (default identity = no threading)
}
-> { actions; orderedPhases; context; fired; }
```

One-shot dispatch. Fires all matching rules in the supplied `phaseOrder` — lower phases complete before higher phases begin, with context threaded between phases. Ordering is the caller's concern (`gen-graph.phaseOrder` builds it from `before`/`after` constraints); dispatch just walks the list. `orderedPhases` in the result is the present-only subsequence of `phaseOrder`. Validates single-phase-per-rule constraint.

**Dispatch sequence:** walk `phaseOrder`; per phase — select this phase's rules (an unphased rule under multi-phase dispatch throws) -> NAC + condition match against the threaded context -> forward-accumulating override suppression (carries to later phases) -> priority sort -> exclusive filter -> fire -> classify-validate (single-phase-per-rule + declared-phase consistency) -> group -> thread context (`combine`/`extract`) into the next phase.

### `dispatchStep` / `dispatchInit` (convergence step)

The convergence LOOP is not gen-dispatch's — it belongs to gen-resolve (`gen-scope.circular`'s Kleene ascent). gen-dispatch supplies the loop's STEP: a `dispatch` pass that threads `fired` and accumulates actions across passes.

```nix
dispatchStep { dispatch } cfg   # -> (self: id: prev -> next)   # cfg = dispatch args minus context/fired
dispatchInit context            # -> { context; fired = {}; accActions = {}; orderedPhases = []; }
```

The step's shape (`self: id: prev`) matches `gen-scope.circular`'s `f: self: id`; the threaded value is `{ context; fired; accActions; orderedPhases }`. `fired` carries once-per-identity dedup across passes; `accActions` accumulates with the exact fold the retired `fixpoint` used. Drive convergence with `gen-scope.circular { init = dispatchInit ctx; eq; } (dispatchStep { inherit dispatch; } cfg)`. Proven byte-identical to the old `fixpoint` — `gen-resolve/spike/gen-derive-loop-step/`.

### `mkRule`

```nix
mkRule {
  condition;            # opaque -- interpreted by match function
  produce;              # id -> ctx -> [ action ]
  nac ? null;           # negative application condition
  identity ? null;      # string for dedup, or null (anonymous)
  priority ? 0;         # higher fires first
  overrides ? [];       # identities of rules this one replaces
  phase ? null;         # phase name for stratified dispatch, or null (single-phase)
}
-> rule
```

### `fromFunction`

```nix
fromFunction : fn -> rule
```

Converts a Nix function into a rule using `builtins.functionArgs` as the condition. Detects `mkIntensional`-wrapped functions (Palmer 2024) via four-predicate check (`isAttrs` + `name`/`__functor`/`closure`) and extracts identity automatically.

```nix
# { host, ... } is the condition -- required arg "host" must be in context
derive.fromFunction ({ host, ... }: [ (fx.spawn { kind = "user"; }) ])

# mkIntensional wrapping adds dedup identity
derive.fromFunction (mkIntensional "host-init" {} ({ host, ... }: [ ... ]))
```

### `fromFunctionMatch`

```nix
fromFunctionMatch : condition -> id -> ctx -> bool
```

Default `match` implementation for `fromFunction` rules. Checks that all required args (non-optional in `functionArgs`) are present in context. Handles `__restricted` conditions from `restrict` by recursively matching both original and extra conditions.

### `mkActions`

```nix
mkActions { phaseName = [ "tag" ... ]; ... }
-> { tag = args: { __action = "tag"; } // args; ...; classify = action -> phaseName; }
```

Generates tagged action constructors and a `classify` function from a phase declaration. Optional -- complex consumers write their own constructors.

### Conflict Resolution

Three strategies, applied in order:

| Strategy | Tier | Mechanism |
|----------|------|-----------|
| Override | Core | Rule names identities it replaces via `overrides` field |
| Priority | Core | Numeric `priority` (higher first), `exclusive` mode |
| Specificity | Adapter | Selector constraint term count via `selectorSpecificity` |

**Resolution order:** override suppression -> priority sort -> specificity (adapter) -> ties fire additively. Equal-priority ties are ordered deterministically by declaration order (a total-order sort, independent of `builtins.sort` stability or rule-list enumeration order).

### Rule Composition

```nix
# Narrow a rule's condition
derive.restrict extraCondition rule

# One rule replaces another (sugar over overrides field)
derive.override original replacement

# Sequential: A's actions feed as context to B
derive.chain { extract; } ruleA ruleB
```

### Phase ordering (moved to gen-graph)

Phase ordering is no longer gen-dispatch's concern. Build the `phaseOrder` list with
[`gen-graph.phaseOrder`](https://github.com/sini/gen-graph) over `before`/`after` entries
and pass it to `dispatch`:

```nix
graph.phaseOrder {
  structural = graph.entryAnywhere;                 # no ordering constraints
  resolution = graph.entryAfter  [ "structural" ];  # after named phases
  collection = graph.entryBefore [ "teardown" ];    # before named phases
}                                                   # -> a valid producers-first topo order
```

### Adapter: gen-select Bridge

```nix
# Bridge gen-select selectors as gen-dispatch conditions
match = derive.adapters.select.mkMatch genSelect;

# CSS-like specificity counting for conflict resolution
derive.adapters.select.selectorSpecificity selector  # -> int
```

## Testing

```bash
cd ci
just ci                    # run all 54 tests
just ci dispatch-basic     # run one suite
just ci dispatch-phases.test-cross-phase-threading  # specific test
```

Requires nix-unit. 54 tests across 10 suites. (Iteration/convergence coverage lives cross-repo now: `gen-resolve/spike/gen-derive-loop-step/` proves the loop⊥step equivalence, and the gen-scope.circular Kleene ascent is tested in gen-scope.)

## Theoretical Foundations

| Paper | Relationship | Used for |
|-------|-------------|----------|
| Forgy (1982) "RETE" | Implements | Condition-action rule dispatch; rule = condition + action production system |
| Ehrig et al. (2006) "Fundamentals of Algebraic Graph Transformation" | Implements | Graph rewriting rules, negative application conditions as first-class `nac` field |
| Arntzenius & Krishnaswami (2016) "Datafun" | **Implements** | Stratified phases: rules dispatched in a caller-supplied stratum order — all rules in phase N complete before phase N+1 begins, with context threaded between phases. (The monotone *fixpoint* reading — iterating dispatch to convergence — moved with the loop to gen-resolve.) |
| Palmer et al. (2024) "Intensional Functions" | Implements | Rule identity via `mkIntensional` detection (four-predicate check: `isAttrs` + `name`/`__functor`/`closure`), dedup |
| Hedin & Magnusson (2003) "JastAdd" | Informed by | Open action types with framework-owned dispatch; aspect-oriented modular attribution |
| Batory (2005) "AHEAD" | Informed by | Feature composition model inspires `restrict`/`override`/`chain` rule combinators |
| Berry & Boudol (1990) "Chemical Abstract Machine" | Informed by | Rules as reactions producing transformations; multiset rewriting as dispatch metaphor |
