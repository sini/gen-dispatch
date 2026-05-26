# gen-derive

Stratified rule dispatch engine with fixpoint convergence, implemented as a pure Nix library.

gen-derive is a **production rule system** (Forgy, 1982) with **stratified phases** (Arntzenius & Krishnaswami, 2016) and **algebraic graph rewriting** vocabulary (Ehrig et al., 2006). Given rules (condition + action producer), a position, and a context, gen-derive answers: "which rules fire here, and what actions do they produce?" It owns dispatch, phase ordering, fixpoint convergence, conflict resolution, and rule dedup. Actions are opaque — the vocabulary belongs to the consumer.

gen-derive is generic. It has no knowledge of NixOS, aspects, policies, or system configuration. It provides dispatch machinery; consumers define what to compute.

## Core Insight

The hard part of rule dispatch is the convergence loop: dispatch rules, extract feedback, widen context, re-dispatch until stable. Hand-rolling this loop caused PRs 408-437 in den (all context-threading regressions). gen-derive extracts the generic protocol — rules declare what they need, gen-derive handles when and how they fire.

## Terminology

| Term | Definition | Source |
|------|-----------|--------|
| Rule | Guarded transformation unit: condition + action producer + identity | Ehrig 2006; Forgy 1982 |
| Condition | Predicate determining when a rule fires | Forgy 1982 (RETE LHS) |
| Action | Opaque tagged value produced when a rule fires | Forgy 1982 (RETE RHS) |
| Phase | Named dispatch group with DAG ordering | Arntzenius 2016 (stratification) |
| Match | Testing a condition against a position | Ehrig 2006 (match morphism) |
| Fixpoint | Convergent dispatch loop with monotone feedback | Arntzenius 2016; Radul 2009 |
| NAC | Negative application condition — pattern that must NOT match | Ehrig 2006 |

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen](https://github.com/sini/gen) | Pure primitives (search, record, identity) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (kinds, instances, collections, refs) |
| [gen-aspects](https://github.com/sini/gen-aspects) | Aspect types (traits, classification, dispatch) |
| [gen-graph](https://github.com/sini/gen-graph) | Graph queries (combinators, traversals, fixpoint) |
| [gen-scope](https://github.com/sini/gen-scope) | Scope graphs (construction, evaluation, resolution) |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (pattern matching over graph positions) |
| [gen-bind](https://github.com/sini/gen-bind) | Module binding (inject args into NixOS modules) |
| [gen-derive](https://github.com/sini/gen-derive) | Rule dispatch (stratified phases, fixpoint, conflict resolution) |

## Usage

```nix
# flake.nix
{
  inputs.gen-derive.url = "github:sini/gen-derive";
  inputs.gen.url = "github:sini/gen";
  outputs = { gen-derive, gen, nixpkgs, ... }:
    let derive = gen-derive.lib;
    in { /* ... */ };
}

# Or without flakes:
let derive = import ./gen-derive { inherit lib; gen = import ./gen {}; };
in { /* ... */ }
```

## Example

Policy-like rules that enrich context and produce typed actions across stratified phases:

```nix
let
  derive = import ./gen-derive { inherit lib; gen = import ./gen {}; };

  # Define action vocabulary — gen-derive classifies but doesn't interpret
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

  result = derive.fixpoint {
    inherit rules;
    context = { host = { name = "igloo"; }; };
    match = derive.fromFunctionMatch;
    classify = fx.classify;
    phases = {
      structural = derive.entryAnywhere {};
      resolution = derive.entryAfter [ "structural" ] {};
    };
    extract = actions:
      lib.foldl' (acc: a:
        if a.__action == "enrich" then acc // { ${a.key} = a.value; } else acc
      ) {} (actions.structural or []);
    combine = ctx: ext: ctx // ext;
    eq = a: b: builtins.attrNames a == builtins.attrNames b;
  };
in {
  result.iterations   # 2 (enrichment converges on second pass)
  result.actions       # { structural = [ enrich, spawn ]; resolution = [ edge ]; }
}
```

## Two-Tier Architecture

gen-derive follows gen's pure/lib two-tier model:

- **Core tier** — depends on gen pure tier only. Conditions are opaque; caller provides `match : condition -> id -> ctx -> bool`.
- **Adapter tier** — imports gen-select. Bridges gen-select selectors into gen-derive conditions with `mkMatch` and `selectorSpecificity`.

Consumers without gen-select can use gen-derive with custom match functions. Consumers with gen-select get selector pattern matching and CSS-like specificity for conflict resolution.

## API Reference

### `dispatch`

```nix
dispatch {
  rules;              # [ rule ]
  id;                 # current position
  context;            # caller-defined context
  match;              # condition -> id -> ctx -> bool
  classify;           # action -> phase name
  phases;             # DAG of phase entries
  exclusive ? false;  # only highest-priority group fires
  fired ? {};         # pre-seeded fired identity set
}
→ { actions; fired; }
```

One-shot dispatch. Fires all matching rules, groups actions by phase in topological order. Validates single-phase-per-rule constraint.

**Dispatch sequence:** NAC check → condition match → override suppression (from matched rules only) → priority sort → exclusive filter → fire → classify → group.

### `fixpoint`

```nix
fixpoint {
  rules; context; match; classify; phases;
  extract;            # actions -> attrset (feedback from actions)
  combine;            # old ctx -> extracted -> new ctx
  eq;                 # old ctx -> new ctx -> bool (stability check)
  id ? null;
  exclusive ? false;
  maxIter ? 100;
}
→ { actions; context; iterations; fired; }
```

Convergent dispatch loop. Calls `dispatch` iteratively — each iteration extracts feedback from actions, widens context, checks stability. Identified rules fire at most once across iterations (dedup via `fired` set). Anonymous rules re-fire each iteration.

### `mkRule`

```nix
mkRule {
  condition;            # opaque — interpreted by match function
  produce;              # id -> ctx -> [ action ]
  nac ? null;           # negative application condition
  identity ? null;      # string for dedup, or null (anonymous)
  priority ? 0;         # higher fires first
  overrides ? [];       # identities of rules this one replaces
}
→ rule
```

### `fromFunction`

```nix
fromFunction : fn -> rule
```

Converts a Nix function into a rule using `builtins.functionArgs` as the condition. Detects `mkIntensional`-wrapped functions (Palmer 2024) via three-field check and extracts identity automatically.

```nix
# { host, ... } is the condition — required arg "host" must be in context
derive.fromFunction ({ host, ... }: [ (fx.spawn { kind = "user"; }) ])

# mkIntensional wrapping adds dedup identity
derive.fromFunction (mkIntensional "host-init" {} ({ host, ... }: [ ... ]))
```

### `fromFunctionMatch`

```nix
fromFunctionMatch : condition -> id -> ctx -> bool
```

Default `match` implementation for `fromFunction` rules. Checks that all required args (non-optional in `functionArgs`) are present in context.

### `mkActions`

```nix
mkActions { phaseName = [ "tag" ... ]; ... }
→ { tag = args: { __action = "tag"; } // args; ...; classify = action -> phaseName; }
```

Generates tagged action constructors and a `classify` function from a phase declaration. Optional — complex consumers write their own constructors.

### Conflict Resolution

Three strategies, applied in order:

| Strategy | Tier | Mechanism |
|----------|------|-----------|
| Override | Core | Rule names identities it replaces via `overrides` field |
| Priority | Core | Numeric `priority` (higher first), `exclusive` mode |
| Specificity | Adapter | Selector constraint term count via `selectorSpecificity` |

**Resolution order:** override suppression → priority sort → specificity (adapter) → ties fire additively.

### Rule Composition

```nix
# Narrow a rule's condition
derive.restrict extraCondition rule

# One rule replaces another (sugar over overrides field)
derive.override original replacement

# Sequential: A's actions feed as context to B
derive.chain { extract; } ruleA ruleB
```

### Phase DAG

```nix
derive.entryAnywhere {}                    # no ordering constraints
derive.entryAfter [ "structural" ] {}      # fires after named phases
derive.entryBefore [ "collection" ] {}     # fires before named phases
derive.entryBetween [ "c" ] [ "a" ] {}     # between two sets
derive.topoSort phases                     # → { result = [ { name; data; } ... ]; }
```

### Adapter: gen-select Bridge

```nix
# Bridge gen-select selectors as gen-derive conditions
match = derive.adapters.select.mkMatch selectLib;

# CSS-like specificity counting for conflict resolution
derive.adapters.select.selectorSpecificity selector  # → int
```

## Testing

```bash
cd templates/ci
just ci                    # run all 55 tests
just ci dispatch-basic     # run one suite
just ci fixpoint.test-converge-two-iterations  # specific test
```

Requires nix-unit. 55 tests across 11 suites.

## Theoretical Foundations

| Paper | Used for |
|-------|----------|
| Forgy (1982) "RETE" | Rule = condition + action; production rule dispatch |
| Ehrig et al. (2006) "Fundamentals of Algebraic Graph Transformation" | Graph rewriting rules, negative application conditions |
| Arntzenius & Krishnaswami (2016) "Datafun" | Stratified phases, monotonic fixpoint |
| Palmer et al. (2024) "Intensional Functions" | Rule identity and dedup via program-point identity |
| Radul & Sussman (2009) "Art of the Propagator" | Monotonic convergence (quiescence) |
| Hedin & Magnusson (2003) "JastAdd" | Open action types with framework-owned dispatch |
| Batory (2005) "AHEAD" | Rule composition (restrict/override/chain as feature refinement) |
| Berry & Boudol (1990) "Chemical Abstract Machine" | Rules as reactions producing transformations |

## License

MIT
