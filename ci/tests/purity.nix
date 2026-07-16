# Purity invariant (gen-prelude design §5): gen-dispatch depends only on gen-prelude —
# no nixpkgs.lib and no gen-algebra. This pins "pure" as a checked property: a stray
# `lib.foo` / `lib.types` / `evalModules` / `genAlgebra` / nixpkgs input creeping back
# into the library source fails CI.
#
# Scope: lib/**.nix (recursively — core/ + adapters/) + the root flake.nix + default.nix.
# NOT ci/ — the test harness legitimately uses nixpkgs.lib (including, here, to scan).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line. Safe here
  # because `#` appears only in comments across these files (no `#` in string literals).
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # Recursively collect every .nix under a directory.
  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  # Tokens signalling a nixpkgs-lib tether, the module-system tier, or a gen-algebra dep.
  forbidden = [
    "nixpkgs"
    "lib."
    "{ lib }"
    "{ lib,"
    "evalModules"
    "mkOption"
    "genAlgebra"
    "gen-algebra"
  ];

  violations = lib.concatMap (
    src:
    map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-dependency-free = {
    expr = violations;
    expected = [ ];
  };
}
