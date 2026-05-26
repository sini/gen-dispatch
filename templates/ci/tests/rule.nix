{ lib, deriveLib, genPure, ... }:
let
  inherit (deriveLib) mkRule fromFunction fromFunctionMatch;
  mkI = genPure.mkIntensional;
in
{
  rule = {
    test-mkrule-defaults = {
      expr = let
        r = mkRule {
          condition = "test";
          produce = _id: _ctx: [];
        };
      in {
        inherit (r) condition nac priority overrides;
        hasIdentity = r.identity == null;
        hasProduce = builtins.isFunction r.produce;
      };
      expected = {
        condition = "test";
        nac = null;
        priority = 0;
        overrides = [];
        hasIdentity = true;
        hasProduce = true;
      };
    };

    test-mkrule-explicit-fields = {
      expr = let
        r = mkRule {
          condition = "test";
          produce = _id: _ctx: [];
          nac = "nac-cond";
          priority = 10;
          overrides = [ "other" ];
          identity = "my-rule";
        };
      in { inherit (r) nac priority overrides identity; };
      expected = {
        nac = "nac-cond";
        priority = 10;
        overrides = [ "other" ];
        identity = "my-rule";
      };
    };

    test-from-function-plain = {
      expr = let
        r = fromFunction ({ host, user ? null, ... }: []);
      in {
        condition = r.condition;
        hasIdentity = r.identity == null;
      };
      expected = {
        condition = { host = false; user = true; };
        hasIdentity = true;
      };
    };

    test-from-function-intensional = {
      expr = let
        fn = mkI "host-guards" {} ({ host, ... }: []);
        r = fromFunction fn;
      in r.identity;
      expected = "host-guards";
    };

    test-from-function-match-satisfied = {
      expr = fromFunctionMatch { host = false; user = true; } "id" { host = {}; };
      expected = true;
    };

    test-from-function-match-unsatisfied = {
      expr = fromFunctionMatch { host = false; user = true; } "id" { user = {}; };
      expected = false;
    };

    test-from-function-match-all-optional = {
      expr = fromFunctionMatch { host = true; user = true; } "id" {};
      expected = true;
    };

    test-from-function-match-restricted = {
      expr = fromFunctionMatch {
        __restricted = true;
        original = { host = false; };
        extra = { env = false; };
      } "id" { host = {}; env = "prod"; };
      expected = true;
    };

    test-from-function-match-restricted-fails = {
      expr = fromFunctionMatch {
        __restricted = true;
        original = { host = false; };
        extra = { env = false; };
      } "id" { host = {}; };
      expected = false;
    };
  };
}
