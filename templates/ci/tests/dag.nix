{ lib, deriveLib, ... }:
let
  inherit (deriveLib) entryAnywhere entryAfter entryBefore topoSort;
in
{
  dag = {
    test-entry-anywhere-shape = {
      expr = entryAnywhere {};
      expected = { data = {}; before = []; after = []; };
    };

    test-entry-after-shape = {
      expr = entryAfter [ "a" ] {};
      expected = { data = {}; before = []; after = [ "a" ]; };
    };

    test-entry-before-shape = {
      expr = entryBefore [ "b" ] {};
      expected = { data = {}; before = [ "b" ]; after = []; };
    };

    test-entry-between-shape = {
      expr = deriveLib.entryBetween [ "c" ] [ "a" ] {};
      expected = { data = {}; before = [ "c" ]; after = [ "a" ]; };
    };

    test-toposort-linear = {
      expr = let
        result = topoSort {
          a = entryAnywhere {};
          b = entryAfter [ "a" ] {};
          c = entryAfter [ "b" ] {};
        };
      in map (e: e.name) result.result;
      expected = [ "a" "b" "c" ];
    };

    test-toposort-before = {
      expr = let
        result = topoSort {
          a = entryAnywhere {};
          b = entryBefore [ "a" ] {};
        };
      in map (e: e.name) result.result;
      expected = [ "b" "a" ];
    };

    test-toposort-single-phase = {
      expr = let
        result = topoSort {
          default = entryAnywhere {};
        };
      in map (e: e.name) result.result;
      expected = [ "default" ];
    };

    test-toposort-cycle-detected = {
      expr = let
        result = topoSort {
          a = entryAfter [ "b" ] {};
          b = entryAfter [ "a" ] {};
        };
      in result ? cycle;
      expected = true;
    };
  };
}
