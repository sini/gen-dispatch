{ lib, deriveLib, genPure, ... }:
let
  inherit (deriveLib) dispatch mkRule fromFunctionMatch mkActions entryAnywhere;
  fx = mkActions { default = [ "act" ]; };
  match = fromFunctionMatch;
  phases = { default = entryAnywhere { }; };
in
{
  conflict = {
    test-priority-ordering = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "low"; }) ];
                priority = 0;
              })
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "high"; }) ];
                priority = 10;
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        map (a: a.v) r.actions.default;
      expected = [ "high" "low" ];
    };

    test-exclusive-mode = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "low"; }) ];
                priority = 0;
              })
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "high"; }) ];
                priority = 10;
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
            exclusive = true;
          };
        in
        map (a: a.v) r.actions.default;
      expected = [ "high" ];
    };

    test-override-suppresses = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "original"; }) ];
                identity = "base-rule";
              })
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { v = "replacement"; }) ];
                identity = "custom-rule";
                overrides = [ "base-rule" ];
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        map (a: a.v) r.actions.default;
      expected = [ "replacement" ];
    };

    test-override-missing-target-noop = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.act { }) ];
                identity = "custom";
                overrides = [ "nonexistent" ];
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        builtins.length r.actions.default;
      expected = 1;
    };
  };
}
