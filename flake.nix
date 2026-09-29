{
  description = "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)";

  # gen-dispatch depends only on gen-prelude (pure, zero-input): builtins via prelude
  # re-exports + the vendored imap0/unique. The former nixpkgs.lib and gen-algebra (dead)
  # dependencies are gone; the convergence LOOP (fixpoint) and group ORDERING (topoSort/
  # entry*) were removed — they now live in gen-resolve and gen-graph respectively.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
  };

  outputs =
    { gen-prelude, ... }:
    {
      # ★ THE ROOT, NOT `./lib`. `./.` and `./lib` were two independent constructions of one
      # value and so free to disagree; there is ONE construction site now, and the two entry
      # paths differ only in who supplies the arguments. Here the flake supplies them, so
      # `follows` governs every argument passed, while the standalone path falls back to
      # `ci/flake.lock`.
      lib = import ./. { prelude = gen-prelude.lib; };
    };
}
