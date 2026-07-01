{
  inputs = {
    gen.url = "github:sini/gen";
    gen-prelude.url = "github:sini/gen-prelude";
    gen-select.url = "github:sini/gen-select";
    # nixpkgs is the CI runner's dependency (test harness, treefmt). gen-dispatch itself
    # (../lib) takes only gen-prelude — see the purity remediation.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen,
      gen-prelude,
      gen-select,
      ...
    }:
    let
      prelude = import "${gen-prelude}/lib";
      genDispatch = import ../lib { inherit prelude; };
      genSelect = import "${gen-select}/lib";
      # Intensional function constructor (Palmer §2.2) — test fixtures only. Inlined
      # from the former gen-algebra.mkIntensional to keep gen-dispatch dependency-free.
      mkIntensional = name: closure: fn: {
        inherit name fn closure;
        __functor = self: self.fn;
      };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-dispatch";
      testModules = ./tests;
      specialArgs = { inherit genDispatch genSelect mkIntensional; };
    };
}
