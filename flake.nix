{
  description = "gen-derive: stratified rule dispatch with fixpoint convergence";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen-algebra.url = "github:sini/gen-algebra";
  };

  outputs =
    {
      nixpkgs,
      gen-algebra,
      ...
    }:
    let
      genDerive = import ./lib {
        lib = nixpkgs.lib;
        genAlgebra = gen-algebra.pure;
      };
    in
    {
      lib = genDerive;
    };
}
