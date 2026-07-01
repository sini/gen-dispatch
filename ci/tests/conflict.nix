{
  lib,
  genDerive,
  ...
}:
let
  inherit (genDerive)
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
  flake.tests.conflict = {
    test-priority-ordering = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "low"; }) ];
                priority = 0;
              })
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "high"; }) ];
                priority = 10;
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
        map (a: a.v) r.actions.default;
      expected = [
        "high"
        "low"
      ];
    };

    test-exclusive-mode = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "low"; }) ];
                priority = 0;
              })
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "high"; }) ];
                priority = 10;
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phaseOrder;
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
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "original"; }) ];
                identity = "base-rule";
              })
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "replacement"; }) ];
                identity = "custom-rule";
                overrides = [ "base-rule" ];
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
        map (a: a.v) r.actions.default;
      expected = [ "replacement" ];
    };

    test-override-missing-target-noop = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { }) ];
                identity = "custom";
                overrides = [ "nonexistent" ];
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

    # E1 (∆-Nets analysis): equal-priority rules must resolve in a deterministic
    # total order (declaration order), independent of builtins.sort stability or
    # rule-list enumeration order. See
    # papers/den-architecture/gen-specs/DELTA-NETS-FOLLOWUPS.md item E1.
    test-equal-priority-deterministic =
      let
        mk =
          v:
          mkRule {
            condition = {
              host = false;
            };
            produce = _id: _ctx: [ (fx.act { inherit v; }) ];
            priority = 5;
          };
        run =
          rules:
          map (a: a.v)
            (dispatch {
              inherit rules;
              id = "x";
              context = {
                host = { };
              };
              inherit match phaseOrder;
              classify = fx.classify;
            }).actions.default;
      in
      {
        expr = {
          ab = run [
            (mk "a")
            (mk "b")
          ];
          ba = run [
            (mk "b")
            (mk "a")
          ];
        };
        expected = {
          ab = [
            "a"
            "b"
          ];
          ba = [
            "b"
            "a"
          ];
        };
      };
  };
}
