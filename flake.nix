{
  description = "gen-derive: stratified rule dispatch with fixpoint convergence";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen.url = "github:sini/gen";
  };

  outputs =
    { nixpkgs, gen, ... }:
    let
      deriveLib = import ./lib {
        lib = nixpkgs.lib;
        genPure = gen.pure;
      };
    in
    {
      lib = deriveLib;
    };
}
