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
  phaseOrder = [ "default" ];
in
{
  flake.tests.dispatch-nac = {
    test-nac-suppresses-rule = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                nac = {
                  monitoring = false;
                };
                produce = _id: _ctx: [ (fx.act { }) ];
              })
            ];
            id = "x";
            context = {
              host = { };
              monitoring = { };
            };
            inherit match phaseOrder;
            classify = fx.classify;
          };
        in
        r.actions;
      expected = { };
    };

    test-nac-null-passes = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { }) ];
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phaseOrder;
            classify = fx.classify;
          };
        in
        builtins.length r.actions.default;
      expected = 1;
    };

    test-nac-not-matching-fires = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                nac = {
                  monitoring = false;
                };
                produce = _id: _ctx: [ (fx.act { }) ];
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phaseOrder;
            classify = fx.classify;
          };
        in
        builtins.length r.actions.default;
      expected = 1;
    };
  };
}
