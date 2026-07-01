{
  description = "gen-derive: relational rule dispatch over ordered phases (the dispatch STEP)";

  # gen-derive depends only on gen-prelude (pure, zero-input): builtins via prelude
  # re-exports + the vendored imap0/unique. The former nixpkgs.lib and gen-algebra (dead)
  # dependencies are gone; the convergence LOOP (fixpoint) and phase ORDERING (topoSort/
  # entry*) were removed — they now live in gen-resolve and gen-graph respectively.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
  };

  outputs =
    { gen-prelude, ... }:
    {
      lib = import ./lib { prelude = gen-prelude.lib; };
    };
}
