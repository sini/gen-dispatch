# gen-dispatch — relational rule dispatch over ordered phases

[![CI](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Relational rule dispatch — the guard→effect **dispatch step**, implemented as a pure Nix library.

gen-dispatch is a **production rule system** (Forgy, 1982) with **stratified phases** (Arntzenius & Krishnaswami, 2016) and **algebraic graph rewriting** vocabulary (Ehrig et al., 2006). Given rules (condition + action producer), a position, and a context, gen-dispatch answers: "which rules fire here, and what actions do they produce?" It owns dispatch, conflict resolution, and rule dedup over a caller-supplied phase order — all rules in phase N complete before phase N+1 begins, with context threaded between phases. Actions are opaque — the vocabulary belongs to the consumer.

gen-dispatch is one dispatch **step**. Two neighbouring concerns are deliberately *not* here: the convergence **loop** that iterates dispatch to a fixpoint (a circular attribute's Kleene ascent) belongs to [gen-resolve](https://github.com/sini/gen-resolve) / `gen-scope.circular`, and phase **ordering** (turning `before`/`after` constraints into a linear order) belongs to [gen-graph](https://github.com/sini/gen-graph) (`phaseOrder`). The loop⊥step split is proven byte-identical by an equivalence oracle maintained in gen-resolve, against the retired in-tree `fixpoint`.

**Dependency class.** gen-dispatch is nixpkgs-lib-free **Class B**: its only dependency is [gen-prelude](https://github.com/sini/gen-prelude) (pure, zero-input) — builtins re-exports plus the vendored `imap0`/`unique`. The former `nixpkgs.lib` and gen-algebra dependencies are gone. The library (`lib/`) is `nixpkgs.lib`-free, enforced by `ci/tests/purity.nix`; nixpkgs is pulled only into `ci/` for the test harness. gen-dispatch is generic — it has no knowledge of NixOS, aspects, policies, or system configuration. It provides dispatch machinery; consumers define what to compute.

## Table of Contents

- [Terminology](#terminology)
- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Usage](#usage)
- [Two-Tier Architecture](#two-tier-architecture)
- [API Reference](#api-reference)
- [Usage Example](#usage-example)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Terminology

| Term | Definition | Source |
|------|-----------|--------|
| Rule | Guarded transformation unit: condition + action producer + identity | Ehrig 2006; Forgy 1982 |
| Condition | Predicate determining when a rule fires | Forgy 1982 (RETE LHS) |
| Action | Opaque tagged value produced when a rule fires | Forgy 1982 (RETE RHS) |
| Phase | Named dispatch group with DAG ordering | Arntzenius 2016 (stratification) |
| Match | Testing a condition against a position | Ehrig 2006 (match morphism) |
| Dispatch step | One guard→effect pass over ordered phases (the unit a convergence loop iterates) | Forgy 1982; Arntzenius 2016 |
| NAC | Negative application condition — pattern that must NOT match | Ehrig 2006 |

## Overview

The hard part of rule dispatch is the generic guard→effect protocol: rules declare *what* they need, and the engine handles *when* and *how* they fire (match, NAC, priority, override, phase threading). Hand-rolling this caused a class of context-threading regressions in den (PRs 408-437). gen-dispatch extracts the protocol as one dispatch **step**.

A **rule** is a guarded action producer (`mkRule` / `fromFunction`). A **dispatch step** (`dispatch`) walks a caller-supplied phase order, and for each phase: matches conditions against the threaded context, applies conflict resolution (override → priority → specificity), fires the survivors, classifies their actions into phases, then threads the resulting context forward into the next phase. The result is `{ actions; orderedPhases; context; fired; }`.

Three concerns meet at a dispatch step, and gen-dispatch owns exactly one of them:

| Concern | Owner | Entry point |
|---------|-------|-------------|
| One guard→effect pass over an ordered phase list | **gen-dispatch** (this lib) | `dispatch` |
| Iterating a step to a fixpoint (a circular attribute's Kleene ascent) | gen-resolve / `gen-scope.circular` | pair a step via `dispatchStep` / `dispatchInit` |
| Turning `before`/`after` constraints into a linear phase order | gen-graph | `phaseOrder` |

Wrapping repeated steps into a convergence loop — extract feedback, widen context, re-dispatch until stable — is a *separable* concern; gen-dispatch exposes `dispatchStep` / `dispatchInit` so a step can be paired with `gen-scope.circular`'s loop, but does not own the loop itself.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch) |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| **gen-dispatch** | **This lib** — relational rule dispatch STEP (stratified phases, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-rebuild](https://github.com/sini/gen-rebuild) | Pure-Nix incremental rebuilder (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |

## Usage

As a flake input — `gen-dispatch.lib` is the value output (no functor call). Class B, so nothing but gen-prelude is pulled transitively; no nixpkgs input is needed:

```nix
# flake.nix
{
  inputs.gen-dispatch.url = "github:sini/gen-dispatch";
  outputs = { gen-dispatch, ... }:
    let dispatch = gen-dispatch.lib;   # takes only gen-prelude, transitively
    in { /* ... */ };
}
```

Without flakes — the standalone shim (`default.nix`) derives gen-prelude from the pinned `flake.lock` (content-addressed, so it stays pure) and needs no `<nixpkgs>`:

```nix
let dispatch = import ./gen-dispatch;                       # prelude auto-derived from the lock
in { /* ... */ }

# or pass an explicit prelude / import the lib directly:
let dispatch = import ./gen-dispatch/lib { prelude = myPrelude; };
in { /* ... */ }
```

## Two-Tier Architecture

gen-dispatch splits into two tiers:

- **Core tier** — depends on gen-prelude only. Conditions are opaque; the caller provides `match : condition -> id -> ctx -> bool`.
- **Adapter tier** — imports gen-select. Bridges gen-select selectors into gen-dispatch conditions with `mkMatch` and CSS-like `selectorSpecificity`.

Consumers without gen-select can use gen-dispatch with custom match functions. Consumers with gen-select get selector pattern matching and CSS-like specificity for conflict resolution. The adapter lives under `lib.adapters.select`; gen-select is a CI-only input (it is not a runtime dependency of the core surface).

## API Reference

The full exported surface is `{ dispatch, dispatchStep, dispatchInit, mkRule, fromFunction, fromFunctionMatch, mkActions, restrict, override, chain, adapters }`, where `adapters = { select = { mkMatch, selectorSpecificity }; }`.

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

One-shot dispatch. Fires all matching rules in the supplied `phaseOrder` — lower phases complete before higher phases begin, with context threaded between phases. Ordering is the caller's concern (`gen-graph.phaseOrder` builds it from `before`/`after` constraints); dispatch just walks the list. `orderedPhases` in the result is the present-only subsequence of `phaseOrder`. Validates the single-phase-per-rule constraint.

**Dispatch sequence:** walk `phaseOrder`; per phase — select this phase's rules (an unphased rule under multi-phase dispatch throws) → NAC + condition match against the threaded context → forward-accumulating override suppression (carries to later phases) → priority sort → exclusive filter → fire → classify-validate (single-phase-per-rule + declared-phase consistency) → group → thread context (`combine`/`extract`) into the next phase.

### `dispatchStep` / `dispatchInit` (convergence step)

The convergence LOOP is not gen-dispatch's — it belongs to gen-resolve (`gen-scope.circular`'s Kleene ascent). gen-dispatch supplies the loop's STEP: a `dispatch` pass that threads `fired` and accumulates actions across passes.

```nix
dispatchStep { dispatch } cfg   # -> (self: id: prev -> next)   # cfg = dispatch args minus context/fired
dispatchInit context            # -> { context; fired = {}; accActions = {}; orderedPhases = []; }
```

The step's shape (`self: id: prev`) matches `gen-scope.circular`'s `f: self: id`; the threaded value is `{ context; fired; accActions; orderedPhases }`. `fired` carries once-per-identity dedup across passes; `accActions` accumulates with the exact fold the retired `fixpoint` used. Drive convergence with `gen-scope.circular { init = dispatchInit ctx; eq; } (dispatchStep { inherit dispatch; } cfg)`. This composition is proven byte-identical to the old in-tree `fixpoint` by an equivalence oracle maintained in gen-resolve.

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

Converts a Nix function into a rule using `builtins.functionArgs` as the condition. Detects `mkIntensional`-wrapped functions (Palmer 2024) via a four-predicate check (`isAttrs` + `name`/`__functor`/`closure`) and extracts identity automatically.

```nix
# { host, ... } is the condition -- required arg "host" must be in context
dispatch.fromFunction ({ host, ... }: [ (fx.spawn { kind = "user"; }) ])

# mkIntensional wrapping adds dedup identity
dispatch.fromFunction (mkIntensional "host-init" {} ({ host, ... }: [ ... ]))
```

### `fromFunctionMatch`

```nix
fromFunctionMatch : condition -> id -> ctx -> bool
```

Default `match` implementation for `fromFunction` rules. Checks that all required args (non-optional in `functionArgs`) are present in context. Handles `__restricted` conditions from `restrict` by recursively matching both the original and extra conditions.

### `mkActions`

```nix
mkActions { phaseName = [ "tag" ... ]; ... }
-> { tag = args: { __action = "tag"; } // args; ...; classify = action -> phaseName; }
```

Generates tagged action constructors and a `classify` function from a phase declaration. Optional — complex consumers write their own constructors.

### Conflict Resolution

Three strategies, applied in order:

| Strategy | Tier | Mechanism |
|----------|------|-----------|
| Override | Core | Rule names identities it replaces via the `overrides` field |
| Priority | Core | Numeric `priority` (higher first), `exclusive` mode |
| Specificity | Adapter | Selector constraint term count via `selectorSpecificity` |

**Resolution order:** override suppression → priority sort → specificity (adapter) → ties fire additively. Equal-priority ties are ordered deterministically by declaration order (a total-order sort, independent of `builtins.sort` stability or rule-list enumeration order).

### Rule Composition

```nix
# Narrow a rule's condition (produces a __restricted condition)
dispatch.restrict extraCondition rule

# One rule replaces another (sugar over the overrides field)
dispatch.override original replacement

# Sequential: A's actions feed as context to B
dispatch.chain { extract; } ruleA ruleB
```

### Phase ordering (delegated to gen-graph)

Phase ordering is no longer gen-dispatch's concern. Build the `phaseOrder` list with [`gen-graph.phaseOrder`](https://github.com/sini/gen-graph) over `before`/`after` entries and pass it to `dispatch`:

```nix
graph.phaseOrder {
  structural = graph.entryAnywhere;                 # no ordering constraints
  resolution = graph.entryAfter  [ "structural" ];  # after named phases
  collection = graph.entryBefore [ "teardown" ];    # before named phases
}                                                   # -> a valid producers-first topo order
```

### Adapter: gen-select bridge (`adapters.select`)

```nix
# Bridge gen-select selectors as gen-dispatch conditions
match = dispatch.adapters.select.mkMatch genSelect;

# CSS-like specificity counting for conflict resolution
dispatch.adapters.select.selectorSpecificity selector  # -> int
```

## Usage Example

Policy-like rules that enrich context and produce typed actions across stratified phases. Ordering comes from `gen-graph.phaseOrder`; a single `dispatch` threads context between phases in that order:

```nix
let
  dispatch = gen-dispatch.lib;
  graph    = gen-graph.lib;

  # Define action vocabulary -- gen-dispatch classifies but doesn't interpret
  fx = dispatch.mkActions {
    structural = [ "spawn" "enrich" ];
    resolution = [ "edge" ];
  };

  rules = [
    # Function signature IS the condition (canTake pattern)
    (dispatch.fromFunction ({ host, ... }: [
      (fx.enrich { key = "isNixos"; value = true; })
      (fx.spawn { kind = "user"; })
    ]))

    # This rule fires only after enrichment adds "isNixos" to context
    (dispatch.mkRule {
      condition = { host = false; isNixos = false; };
      produce = _id: _ctx: [ (fx.edge { target = "logging"; }) ];
      identity = "nixos-edges";
    })
  ];

  cfg = {
    inherit rules;
    id = null;
    match = dispatch.fromFunctionMatch;
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
  result = dispatch.dispatch (cfg // { context = { host = { name = "igloo"; }; }; });
in
  result.actions   # { structural = [ enrich, spawn ]; resolution = [ edge ]; }
```

**When you need a convergence loop** (genuinely cyclic rules that must iterate to a fixpoint), the LOOP is gen-resolve's, not gen-dispatch's — wrap the step with `gen-scope.circular`:

```nix
let
  scope = gen-scope.lib;
  step  = dispatch.dispatchStep { inherit (dispatch) dispatch; } cfg;   # self:id:prev -> next
in
  (scope.circular {
    init = dispatch.dispatchInit { host = { name = "igloo"; }; };       # { context; fired; accActions; ... }
    eq   = a: b: builtins.attrNames a.context == builtins.attrNames b.context;
  } step) {} null                                                        # -> { context; fired; accActions; ... }
```

`dispatchStep` threads `fired` (once-per-identity dedup) and accumulates actions across passes exactly as the retired `fixpoint` did; `gen-scope.circular` drives the Kleene ascent.

## Testing

Tests use [nix-unit](https://github.com/nix-community/nix-unit); the CI flake (`ci/`) pins nixpkgs for the harness while the library (`../lib`) takes only gen-prelude. The library is `nixpkgs.lib`-free, enforced by the `purity` suite (`ci/tests/purity.nix`).

```bash
nix flake check ./ci                       # all suites + the purity check
nix build ./ci#formatter.x86_64-linux      # then run ./result/bin/* . to format
nix repl --impure --file ci/repl.nix       # all exports in scope for interactive use
```

There are **55 tests across 10 suites** (`rule`, `actions`, `dispatch-basic`, `dispatch-phases`, `dispatch-nac`, `conflict`, `compose`, `adapter-select`, `integration`, `purity`). Iteration/convergence coverage lives cross-repo now: the loop⊥step equivalence oracle is maintained in gen-resolve, and the `gen-scope.circular` Kleene ascent is tested in gen-scope.

## Theoretical Foundations

| Paper | Relationship | Used for |
|-------|-------------|----------|
| Forgy (1982) "RETE" | Implements | Condition-action rule dispatch; rule = condition + action production system |
| Ehrig et al. (2006) "Fundamentals of Algebraic Graph Transformation" | Implements | Graph rewriting rules, negative application conditions as a first-class `nac` field |
| Arntzenius & Krishnaswami (2016) "Datafun" | **Implements** | Stratified phases: rules dispatched in a caller-supplied stratum order — all rules in phase N complete before phase N+1 begins, with context threaded between phases. (The monotone *fixpoint* reading — iterating dispatch to convergence — moved with the loop to gen-resolve.) |
| Palmer et al. (2024) "Intensional Functions" | Implements | Rule identity via `mkIntensional` detection (four-predicate check: `isAttrs` + `name`/`__functor`/`closure`), dedup |
| Hedin & Magnusson (2003) "JastAdd" | Informed by | Open action types with framework-owned dispatch; aspect-oriented modular attribution |
| Batory (2005) "AHEAD" | Informed by | Feature composition model inspires the `restrict`/`override`/`chain` rule combinators |
| Berry & Boudol (1990) "Chemical Abstract Machine" | Informed by | Rules as reactions producing transformations; multiset rewriting as a dispatch metaphor |

## License

MIT — see `LICENSE`.
