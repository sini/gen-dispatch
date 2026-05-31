{ lib, genDerive, ... }:
let
  inherit (genDerive)
    dispatch
    mkRule
    fromFunctionMatch
    mkActions
    entryAnywhere
    entryAfter
    ;
  fx = mkActions {
    structural = [ "spawn" ];
    resolution = [ "edge" ];
  };
  match = fromFunctionMatch;
  phases = {
    structural = entryAnywhere { };
    resolution = entryAfter [ "structural" ] { };
  };
in
{
  flake.tests.dispatch-phases = {
    test-ordered-phases-topological = {
      expr =
        (dispatch {
          rules = [
            (mkRule {
              condition = {
                host = false;
              };
              phase = "structural";
              produce = _: _: [ (fx.spawn { }) ];
            })
            (mkRule {
              condition = {
                host = false;
              };
              phase = "resolution";
              produce = _: _: [ (fx.edge { }) ];
            })
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match phases;
          classify = fx.classify;
        }).orderedPhases;
      expected = [
        "structural"
        "resolution"
      ];
    };

    test-actions-grouped-by-phase = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                phase = "structural";
                produce = _: _: [ (fx.spawn { }) ];
              })
              (mkRule {
                condition = {
                  host = false;
                };
                phase = "resolution";
                produce = _: _: [ (fx.edge { }) ];
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phases;
            classify = fx.classify;
          };
        in
        builtins.length r.actions.structural + builtins.length r.actions.resolution;
      expected = 2;
    };

    test-cross-phase-threading = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                phase = "structural";
                produce = _: _: [ (fx.spawn { }) ];
                identity = "s";
              })
              (mkRule {
                condition = {
                  flag = false;
                };
                phase = "resolution";
                produce = _: _: [ (fx.edge { }) ];
                identity = "r";
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phases;
            classify = fx.classify;
            extract = actions: if (actions.structural or [ ]) != [ ] then { flag = true; } else { };
            combine = ctx: ext: ctx // ext;
          };
        in
        builtins.length (r.actions.resolution or [ ]);
      expected = 1;
    };

    test-forward-override = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                phase = "structural";
                produce = _: _: [ (fx.spawn { }) ];
                identity = "s";
                overrides = [ "r" ];
              })
              (mkRule {
                condition = {
                  host = false;
                };
                phase = "resolution";
                produce = _: _: [ (fx.edge { }) ];
                identity = "r";
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match phases;
            classify = fx.classify;
          };
        in
        r.actions.resolution or [ ];
      expected = [ ];
    };

    test-phase-consistency-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch {
          rules = [
            (mkRule {
              condition = {
                host = false;
              };
              phase = "structural";
              produce = _: _: [ (fx.edge { }) ];
            })
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match phases;
          classify = fx.classify;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-missing-phase-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch {
          rules = [
            (mkRule {
              condition = {
                host = false;
              };
              produce = _: _: [ (fx.spawn { }) ];
            })
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match phases;
          classify = fx.classify;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-multi-phase-rule-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch {
          rules = [
            (mkRule {
              condition = {
                host = false;
              };
              phase = "structural";
              produce = _: _: [
                (fx.spawn { })
                (fx.edge { })
              ];
            })
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match phases;
          classify = fx.classify;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-single-phase-backward-compat = {
      expr =
        let
          fx1 = mkActions { default = [ "act" ]; };
          r = dispatch {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _: _: [ (fx1.act { }) ];
              })
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = fx1.classify;
            phases = {
              default = entryAnywhere { };
            };
          };
        in
        {
          p = r.orderedPhases;
          n = builtins.length r.actions.default;
        };
      expected = {
        p = [ "default" ];
        n = 1;
      };
    };
  };
}
