{
  inputs = {
    gen.url = "github:sini/gen";
    gen-algebra.url = "github:sini/gen-algebra";
    gen-select.url = "github:sini/gen-select";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{ gen, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      genAlgebra = inputs.gen-algebra.lib;
      genDerive = import ../lib { inherit lib genAlgebra; };
      genSelect = import "${inputs.gen-select}/lib" { inherit lib genAlgebra; };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-derive";
      testModules = ./tests;
      specialArgs = { inherit genDerive genSelect genAlgebra; };
    };
}
