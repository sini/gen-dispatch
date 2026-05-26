{ lib, deriveLib, ... }:
let
  fx = deriveLib.mkActions {
    structural = [ "spawn" "enrich" ];
    resolution = [ "edge" "drop" ];
  };
in
{
  actions = {
    test-constructor-shape = {
      expr = fx.spawn { nodeId = "test"; };
      expected = { __action = "spawn"; nodeId = "test"; };
    };

    test-classify-structural = {
      expr = fx.classify { __action = "spawn"; };
      expected = "structural";
    };

    test-classify-resolution = {
      expr = fx.classify { __action = "edge"; };
      expected = "resolution";
    };

    test-classify-unknown-throws = {
      expr = builtins.tryEval (fx.classify { __action = "unknown"; });
      expected = { success = false; value = false; };
    };
  };
}
