# gen-dispatch — relational rule dispatch over ordered groups

[![CI](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-dispatch/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Relational rule dispatch — the guard→effect **dispatch step**, implemented as a pure Nix library.

gen-dispatch is a **production rule system** (Forgy, 1982) with **stratified groups** (Arntzenius & Krishnaswami, 2016) and **algebraic graph rewriting** vocabulary (Ehrig et al., 2006). Given rules (condition + action producer), a position, and a context, gen-dispatch answers: "which rules fire here, and what actions do they produce?" It owns rule evaluation and conflict resolution over a caller-supplied group order — all rules in group N complete before group N+1 begins, with context threaded between groups. Actions are opaque — the vocabulary belongs to the consumer.

gen-dispatch is one dispatch **step** — a pure function of `(rules, context)`. Two neighbouring concerns are deliberately *not* here: the convergence **loop** that iterates dispatch to a fixpoint (a circular attribute's Kleene ascent) belongs to [gen-resolve](https://github.com/sini/gen-resolve) / `gen-scope.circular`, and group **ordering** (turning `before`/`after` constraints into a linear order) belongs to [gen-graph](https://github.com/sini/gen-graph). Iterate by threading pure domain state through repeated one-shot dispatch; because a group order is a topological sort and the action set is a function of the converged state, the split holds without any cross-pass bookkeeping inside dispatch.

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
| Group | Named dispatch stratum with DAG ordering | Arntzenius 2016 (stratification) |
| Match | Testing a condition against a position | Ehrig 2006 (match morphism) |
| Dispatch step | One guard→effect pass over ordered groups (the unit a convergence loop iterates) | Forgy 1982; Arntzenius 2016 |
| NAC | Negative application condition — pattern that must NOT match | Ehrig 2006 |

## Overview

The hard part of rule dispatch is the generic guard→effect protocol: rules declare *what* they need, and the engine handles *when* and *how* they fire (match, NAC, priority, override, phase threading). Hand-rolling this caused a class of context-threading regressions in den (PRs 408-437). gen-dispatch extracts the protocol as one dispatch **step**.

A **rule** is a guarded action producer (`mkRule` / `fromFunction`). A **dispatch step** (`dispatch`) walks a caller-supplied group order, and for each group: matches conditions against the threaded context, applies conflict resolution (override → priority → specificity), fires the survivors, classifies their actions into groups, then threads the resulting context forward into the next group. The result is `{ actions; orderedGroups; context; }`.

Three concerns meet at a dispatch step, and gen-dispatch owns exactly one of them:

| Concern | Owner | Entry point |
|---------|-------|-------------|
| One guard→effect pass over an ordered group list | **gen-dispatch** (this lib) | `dispatch` |
| Iterating a step to a fixpoint (a circular attribute's Kleene ascent) | gen-resolve / `gen-scope.circular` | thread domain state through repeated `dispatch` |
| Turning `before`/`after` constraints into a linear group order | gen-graph | a topological sort |

Wrapping repeated steps into a convergence loop — extract feedback, widen context, re-dispatch until stable — is a *separable* concern owned by `gen-scope.circular`. gen-dispatch stays a pure step: the caller threads the domain state and reads the actions off the converged state. See [Convergence](#convergence-the-loop-is-gen-resolves) below.

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base (builtins re-exports + vendored lib utils) |
| [gen-algebra](https://github.com/sini/gen-algebra) | Pure primitives (record, search monad, either, intensional identity) |
| [gen-types](https://github.com/sini/gen-types) | Clean-room MIT structural type checker (leaf/poly checkers; `verify: v → null\|err`) |
| [gen-merge](https://github.com/sini/gen-merge) | Byte-mode module merge engine (`evalModuleTree`, byte-identical to nixpkgs `lib.evalModules` over the priority subset) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs); re-hosted on gen-merge |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect type system (traits, classification, dispatch); re-hosted on gen-merge |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator (demand-driven, \_eval memoization, circular attributes) |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (traversal, condensation, phaseOrder) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject external args into NixOS modules) |
| **gen-dispatch** | **This lib** — Relational rule dispatch STEP (stratified groups, conflict resolution) |
| [gen-resolve](https://github.com/sini/gen-resolve) | Demand-driven RAG evaluator over scope graphs (attribute schedule + convergence loop) |
| [gen-rebuild](https://github.com/sini/gen-rebuild) | Pure-Nix incremental rebuilder (change propagation, AFFECTED set) |
| [gen-vars](https://github.com/sini/gen-vars) | Pure-Nix vars/secrets (den-agnostic) |
| [gen-flake](https://github.com/sini/gen-flake) | The nixpkgs boundary — compose purely, inject resolved values, build NixOS systems (value-injection) |

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

The full exported surface is `{ dispatch, mkRule, fromFunction, fromFunctionMatch, mkActions, restrict, override, chain, adapters }`, where `adapters = { select = { mkMatch, selectorSpecificity }; }`.

### `dispatch`

```nix
dispatch {
  rules;              # [ rule ]
  id;                 # current position
  context;            # caller-defined context
  match;              # condition -> id -> ctx -> bool
  classify;           # action -> group name
  groupOrder;         # [ groupName ] — pre-ordered (e.g. a gen-graph topo sort); dispatch does NOT sort
  exclusive ? false;  # only highest-priority group fires
  extract ? (_: {});       # { group = [action]; } -> ctx delta (per-group threading; default no-op)
  combine ? (ctx: _: ctx); # ctx -> delta -> ctx (default identity = no threading)
}
-> { actions; orderedGroups; context; }
```

One-shot dispatch, a pure function of `(rules, context)`. Fires all matching rules in the supplied `groupOrder` — lower groups complete before higher groups begin, with context threaded between groups. Ordering is the caller's concern (`gen-graph` builds it from `before`/`after` constraints); dispatch just walks the list. `orderedGroups` in the result is the present-only subsequence of `groupOrder`. Validates the single-group-per-rule constraint.

**Dispatch sequence:** walk `groupOrder`; per group — select this group's rules (an ungrouped rule under multi-group dispatch throws) → NAC + condition match against the threaded context → forward-accumulating override suppression (carries to later groups) → priority sort → exclusive filter → fire → classify-validate (single-group-per-rule + declared-group consistency) → group → thread context (`combine`/`extract`) into the next group.

### Convergence (the loop is gen-resolve's)

`dispatch` is a pure step: the same `context` always yields the same actions, so it owns no iteration. When rules are genuinely cyclic and must iterate to a fixpoint, the LOOP belongs to gen-resolve (`gen-scope.circular`'s Kleene ascent). The blessed composition threads **plain domain state** through repeated one-shot dispatch:

```nix
# one-shot dispatch as the step: next state = the context dispatch threads out
step = _self: _id: ctx: (dispatch (cfg // { context = ctx; })).context;

# gen-scope.circular iterates the step to a fixpoint over the domain state
converged = (scope.circular { init = ctx0; eq = stateEq; } step) { } null;

# one post-convergence dispatch reads the actions off the fixpoint
result = dispatch (cfg // { context = converged; });   # result.actions, result.orderedGroups
```

Recomputing at the fixpoint makes the action set a function of the **converged state**, never the iteration path — a confluence guarantee. That is why dispatch keeps no cross-pass `fired` set: the "double-emit across passes" problem exists only under an accumulate-across-passes model, and cannot arise when each pass recomputes from scratch and the actions are taken from the fixpoint. (The retired `dispatchStep` / `dispatchInit` pair was the byte-identical migration seam off the old in-tree `fixpoint`; with the recompute pattern blessed, it is gone.)

### `mkRule`

```nix
mkRule {
  condition;            # opaque -- interpreted by match function
  produce;              # id -> ctx -> [ action ]
  nac ? null;           # negative application condition
  identity ? null;      # string for dedup, or null (anonymous)
  priority ? 0;         # higher fires first
  overrides ? [];       # identities of rules this one replaces
  group ? null;         # group name for stratified dispatch, or null (single-group)
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
mkActions { groupName = [ "tag" ... ]; ... }
-> { tag = args: { __action = "tag"; } // args; ...; classify = action -> groupName; }
```

Generates tagged action constructors and a `classify` function from a group declaration. Optional — complex consumers write their own constructors.

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

### Group ordering (delegated to gen-graph)

Group ordering is no longer gen-dispatch's concern. Build the `groupOrder` list with [gen-graph](https://github.com/sini/gen-graph)'s topological sort (`phaseOrder`) over `before`/`after` entries and pass it to `dispatch`:

```nix
graph.phaseOrder {
  structural = graph.entryAnywhere;                 # no ordering constraints
  resolution = graph.entryAfter  [ "structural" ];  # after named groups
  collection = graph.entryBefore [ "teardown" ];    # before named groups
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

Policy-like rules that enrich context and produce typed actions across stratified groups. Ordering comes from `gen-graph`; a single `dispatch` threads context between groups in that order:

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
    # group ORDERING is gen-graph's job
    groupOrder = graph.phaseOrder {
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

**When you need a convergence loop** (genuinely cyclic rules that must iterate to a fixpoint), the LOOP is gen-resolve's, not gen-dispatch's — thread the domain state through `gen-scope.circular` and read the actions off the fixpoint:

```nix
let
  scope = gen-scope.lib;
  # step: next state = the context this pass threads out (one-shot dispatch)
  step  = _self: _id: ctx: (dispatch.dispatch (cfg // { context = ctx; })).context;

  converged =
    (scope.circular {
      init = { host = { name = "igloo"; }; };
      eq   = a: b: builtins.attrNames a == builtins.attrNames b;
    } step) {} null;
in
  (dispatch.dispatch (cfg // { context = converged; })).actions   # actions as a function of the fixpoint
```

The action set is a function of the **converged state**, not the iteration path (confluence), so a rule cannot double-emit across passes — the accumulate-across-passes bookkeeping the retired `fixpoint` / `dispatchStep` needed is unnecessary. `gen-scope.circular` drives the Kleene ascent.

## Testing

Tests use [nix-unit](https://github.com/nix-community/nix-unit); the CI flake (`ci/`) pins nixpkgs for the harness while the library (`../lib`) takes only gen-prelude. The library is `nixpkgs.lib`-free, enforced by the `purity` suite (`ci/tests/purity.nix`).

```bash
nix flake check ./ci                       # all suites + the purity check
nix build ./ci#formatter.x86_64-linux      # then run ./result/bin/* . to format
nix repl --impure --file ci/repl.nix       # all exports in scope for interactive use
```

There are **53 tests across 10 suites** (`rule`, `actions`, `dispatch-basic`, `dispatch-groups`, `dispatch-nac`, `conflict`, `compose`, `adapter-select`, `integration`, `purity`). Iteration/convergence coverage lives cross-repo now: the `gen-scope.circular` Kleene ascent is tested in gen-scope, and the loop⊥step composition (one-shot dispatch threaded to a fixpoint) is exercised by consumers such as gen-resolve.

## Theoretical Foundations

| Paper | Relationship | Used for |
|-------|-------------|----------|
| Forgy (1982) "RETE" | Implements | Condition-action rule dispatch; rule = condition + action production system |
| Ehrig et al. (2006) "Fundamentals of Algebraic Graph Transformation" | Implements | Graph rewriting rules, negative application conditions as a first-class `nac` field |
| Arntzenius & Krishnaswami (2016) "Datafun" | **Implements** | Stratified groups: rules dispatched in a caller-supplied stratum order — all rules in group N complete before group N+1 begins, with context threaded between groups. (The monotone *fixpoint* reading — iterating dispatch to convergence — moved with the loop to gen-resolve.) |
| Palmer et al. (2024) "Intensional Functions" | Implements | Rule identity via `mkIntensional` detection (four-predicate check: `isAttrs` + `name`/`__functor`/`closure`), dedup |
| Hedin & Magnusson (2003) "JastAdd" | Informed by | Open action types with framework-owned dispatch; aspect-oriented modular attribution |
| Batory (2005) "AHEAD" | Informed by | Feature composition model inspires the `restrict`/`override`/`chain` rule combinators |
| Berry & Boudol (1990) "Chemical Abstract Machine" | Informed by | Rules as reactions producing transformations; multiset rewriting as a dispatch metaphor |

## License

MIT — see `LICENSE`.
