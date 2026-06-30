{
  description = "gen-derive: stratified rule dispatch with fixpoint convergence";

  # gen-derive depends only on gen-prelude (pure, zero-input): builtins via prelude
  # re-exports + the vendored filterAttrs/imap0/unique/toposort. The former nixpkgs.lib
  # and gen-algebra (dead) dependencies are gone — see the purity remediation.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
  };

  outputs =
    { gen-prelude, ... }:
    {
      lib = import ./lib { prelude = gen-prelude.lib; };
    };
}
