{ lib, genDispatch, ... }:
let
  inherit (genDispatch)
    dispatch
    mkRule
    fromFunctionMatch
    mkActions
    ;
  fx = mkActions { default = [ "act" ]; };
  match = fromFunctionMatch;
  groupOrder = [ "default" ];
in
{
  flake.tests.dispatch-nac = {
    test-nac-suppresses-rule = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  nac = {
                    monitoring = false;
                  };
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { }) ])
              )
            ];
            id = "x";
            context = {
              host = { };
              monitoring = { };
            };
            inherit match;
            classify = fx.classify;
            inherit groupOrder;
          };
        in
        r.actions;
      expected = { };
    };

    test-nac-null-passes = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule { } {
                host = false;
              } (_id: _ctx: [ (fx.act { }) ]))
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = fx.classify;
            inherit groupOrder;
          };
        in
        builtins.length r.actions.default;
      expected = 1;
    };

    test-nac-not-matching-fires = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  nac = {
                    monitoring = false;
                  };
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { }) ])
              )
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = fx.classify;
            inherit groupOrder;
          };
        in
        builtins.length r.actions.default;
      expected = 1;
    };
  };
}
