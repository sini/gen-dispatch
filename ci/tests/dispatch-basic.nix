{
  lib,
  genDispatch,
  ...
}:
let
  inherit (genDispatch)
    dispatch
    fromFunction
    fromFunctionMatch
    mkActions
    ;
  fx = mkActions { default = [ "act" ]; };
  match = fromFunctionMatch;
  groupOrder = [ "default" ];
in
{
  flake.tests.dispatch-basic = {
    test-single-rule-fires = {
      expr =
        let
          r = dispatch {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ])) ];
            id = "host:igloo";
            context = {
              host = { };
            };
            inherit match groupOrder;
            classify = fx.classify;
          };
        in
        r.actions;
      expected = {
        default = [
          {
            __action = "act";
            v = 1;
          }
        ];
      };
    };

    test-no-match-empty = {
      expr =
        let
          r = dispatch {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { }) ])) ];
            id = "x";
            context = { };
            inherit match groupOrder;
            classify = fx.classify;
          };
        in
        r.actions;
      expected = { };
    };

    test-multiple-rules = {
      expr =
        let
          r = dispatch {
            rules = [
              (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ]))
              (fromFunction ({ host, ... }: [ (fx.act { v = 2; }) ]))
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match groupOrder;
            classify = fx.classify;
          };
        in
        r.actions.default;
      expected = [
        {
          __action = "act";
          v = 1;
        }
        {
          __action = "act";
          v = 2;
        }
      ];
    };

  };
}
