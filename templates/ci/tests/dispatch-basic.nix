{ lib, deriveLib, genPure, ... }:
let
  inherit (deriveLib) dispatch fromFunction fromFunctionMatch mkRule mkActions entryAnywhere;
  fx = mkActions { default = [ "act" ]; };
  match = fromFunctionMatch;
  phases = { default = entryAnywhere { }; };
in
{
  dispatch-basic = {
    test-single-rule-fires = {
      expr =
        let
          r = dispatch {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ])) ];
            id = "host:igloo";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        r.actions;
      expected = {
        default = [ { __action = "act"; v = 1; } ];
      };
    };

    test-no-match-empty = {
      expr =
        let
          r = dispatch {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { }) ])) ];
            id = "x";
            context = { };
            inherit match phases;
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
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        r.actions.default;
      expected = [
        { __action = "act"; v = 1; }
        { __action = "act"; v = 2; }
      ];
    };

    test-fired-tracks-identity = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { }) ];
                identity = "my-rule";
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        r.fired;
      expected = { "my-rule" = true; };
    };

    test-fired-skips-anonymous = {
      expr =
        let
          r = dispatch {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { }) ])) ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        r.fired;
      expected = { };
    };
  };
}
