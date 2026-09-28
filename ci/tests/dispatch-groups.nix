{ lib, genDispatch, ... }:
let
  inherit (genDispatch)
    dispatch
    mkRule
    fromFunctionMatch
    mkActions
    ;
  fx = mkActions {
    structural = [ "spawn" ];
    resolution = [ "edge" ];
  };
  match = fromFunctionMatch;
  # caller supplies the pre-ordered group list (gen-graph's job); dispatch walks it,
  # it does not sort.
  groupOrder = [
    "structural"
    "resolution"
  ];
in
{
  flake.tests.dispatch-groups = {
    # dispatch no longer sorts — orderedGroups is the present-only subsequence of the
    # caller-supplied groupOrder (group ordering is gen-graph's concern).
    test-ordered-groups-present-subsequence = {
      expr =
        (dispatch { } {
          rules = [
            (mkRule
              {
                group = "structural";
              }
              {
                host = false;
              }
              (_: _: [ (fx.spawn { }) ])
            )
            (mkRule
              {
                group = "resolution";
              }
              {
                host = false;
              }
              (_: _: [ (fx.edge { }) ])
            )
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match;
          classify = fx.classify;
          inherit groupOrder;
        }).orderedGroups;
      expected = [
        "structural"
        "resolution"
      ];
    };

    test-actions-grouped-by-group = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  group = "structural";
                }
                {
                  host = false;
                }
                (_: _: [ (fx.spawn { }) ])
              )
              (mkRule
                {
                  group = "resolution";
                }
                {
                  host = false;
                }
                (_: _: [ (fx.edge { }) ])
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
        builtins.length r.actions.structural + builtins.length r.actions.resolution;
      expected = 2;
    };

    test-cross-group-threading = {
      expr =
        let
          r =
            dispatch
              {
                extract = actions: if (actions.structural or [ ]) != [ ] then { flag = true; } else { };
                combine = ctx: ext: ctx // ext;
              }
              {
                rules = [
                  (mkRule
                    {
                      group = "structural";
                      identity = "s";
                    }
                    {
                      host = false;
                    }
                    (_: _: [ (fx.spawn { }) ])
                  )
                  (mkRule
                    {
                      group = "resolution";
                      identity = "r";
                    }
                    {
                      flag = false;
                    }
                    (_: _: [ (fx.edge { }) ])
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
        builtins.length (r.actions.resolution or [ ]);
      expected = 1;
    };

    test-forward-override = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  group = "structural";
                  identity = "s";
                  overrides = [ "r" ];
                }
                {
                  host = false;
                }
                (_: _: [ (fx.spawn { }) ])
              )
              (mkRule
                {
                  group = "resolution";
                  identity = "r";
                }
                {
                  host = false;
                }
                (_: _: [ (fx.edge { }) ])
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
        r.actions.resolution or [ ];
      expected = [ ];
    };

    test-group-consistency-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch { } {
          rules = [
            (mkRule
              {
                group = "structural";
              }
              {
                host = false;
              }
              (_: _: [ (fx.edge { }) ])
            )
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match;
          classify = fx.classify;
          inherit groupOrder;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-missing-group-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch { } {
          rules = [
            (mkRule { } {
              host = false;
            } (_: _: [ (fx.spawn { }) ]))
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match;
          classify = fx.classify;
          inherit groupOrder;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-multi-group-rule-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch { } {
          rules = [
            (mkRule
              {
                group = "structural";
              }
              {
                host = false;
              }
              (
                _: _: [
                  (fx.spawn { })
                  (fx.edge { })
                ]
              )
            )
          ];
          id = "x";
          context = {
            host = { };
          };
          inherit match;
          classify = fx.classify;
          inherit groupOrder;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-single-group-backward-compat = {
      expr =
        let
          fx1 = mkActions { default = [ "act" ]; };
          r = dispatch { } {
            rules = [
              (mkRule { } {
                host = false;
              } (_: _: [ (fx1.act { }) ]))
            ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = fx1.classify;
            groupOrder = [ "default" ];
          };
        in
        {
          g = r.orderedGroups;
          n = builtins.length r.actions.default;
        };
      expected = {
        g = [ "default" ];
        n = 1;
      };
    };
  };
}
