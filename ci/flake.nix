{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    gen-prelude.url = "github:sini/gen-prelude";
    gen-select.url = "github:sini/gen-select";
    # nixpkgs is the CI runner's dependency (test harness, treefmt). gen-dispatch itself
    # (../lib) takes only gen-prelude — see the purity remediation.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-prelude,
      gen-select,
      ...
    }:
    let
      prelude = import "${gen-prelude}/lib";
      genDispatch = import ../lib { inherit prelude; };
      # `.lib`, NOT A PATH IMPORT. `${gen-select}/lib` is a FUNCTION taking `{ algebra }`, and
      # gen-select's root names `.lib` as the channel a flake consumer takes: it is that same
      # application, with gen-select's own lock supplying the argument this flake declares no
      # input for. The path form binds the lambda itself, and a lambda only reads as the
      # attrset the suite indexes until the callee acquires a formal.
      genSelect = gen-select.lib;
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-dispatch";
      testModules = ./tests;
      # `prelude` reaches the suite because `tests/entry.nix` applies the STANDALONE root entry with
      # explicit arguments — which is what keeps that cell pure, since supplying the formal means the
      # shim's fetching default is never forced. It is the SAME instance `genDispatch` above is built
      # from, so the two sides of that comparison differ in entry point and in nothing else.
      specialArgs = { inherit genDispatch genSelect prelude; };
    };
}
