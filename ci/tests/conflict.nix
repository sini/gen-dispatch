{
  lib,
  genDispatch,
  ...
}:
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

  uMk =
    v: priority:
    mkRule {
      identity = v;
      inherit priority;
    } { host = false; } (_id: _ctx: [ (fx.act { inherit v; }) ]);
  uRun =
    opts: rules:
    dispatch opts {
      inherit rules;
      id = "x";
      context = {
        host = { };
      };
      inherit match;
      classify = fx.classify;
      inherit groupOrder;
    };
in
{
  flake.tests.conflict = {
    test-priority-ordering = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  priority = 0;
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { v = "low"; }) ])
              )
              (mkRule
                {
                  priority = 10;
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { v = "high"; }) ])
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
        map (a: a.v) r.actions.default;
      expected = [
        "high"
        "low"
      ];
    };

    test-exclusive-mode = {
      expr =
        let
          r =
            dispatch
              {
                exclusive = true;
              }
              {
                rules = [
                  (mkRule
                    {
                      priority = 0;
                    }
                    {
                      host = false;
                    }
                    (_id: _ctx: [ (fx.act { v = "low"; }) ])
                  )
                  (mkRule
                    {
                      priority = 10;
                    }
                    {
                      host = false;
                    }
                    (_id: _ctx: [ (fx.act { v = "high"; }) ])
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
        map (a: a.v) r.actions.default;
      expected = [ "high" ];
    };

    test-override-suppresses = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  identity = "base-rule";
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { v = "original"; }) ])
              )
              (mkRule
                {
                  identity = "custom-rule";
                  overrides = [ "base-rule" ];
                }
                {
                  host = false;
                }
                (_id: _ctx: [ (fx.act { v = "replacement"; }) ])
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
        map (a: a.v) r.actions.default;
      expected = [ "replacement" ];
    };

    test-override-missing-target-noop = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (mkRule
                {
                  identity = "custom";
                  overrides = [ "nonexistent" ];
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

    # E1 (∆-Nets analysis): equal-priority rules must resolve in a deterministic
    # total order (declaration order), independent of builtins.sort stability or
    # rule-list enumeration order.
    test-equal-priority-deterministic =
      let
        mk =
          v:
          mkRule
            {
              priority = 5;
            }
            {
              host = false;
            }
            (_id: _ctx: [ (fx.act { inherit v; }) ]);
        run =
          rules:
          map (a: a.v)
            (dispatch { } {
              inherit rules;
              id = "x";
              context = {
                host = { };
              };
              inherit match;
              classify = fx.classify;
              inherit groupOrder;
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

    # `unique` (den-hoag-ro5cu): more than one rule surviving the exclusive filter is refused by name
    # (the message golden is `ci/tests-error.nix`'s `conflict` cell); one survivor is served; with
    # `unique` unset a tie fires additively, as before.
    test-unique-one-survivor-is-served = {
      expr =
        map (a: a.v)
          (uRun
            {
              exclusive = true;
              unique = true;
            }
            [
              (uMk "low" 0)
              (uMk "high" 10)
            ]
          ).actions.default;
      expected = [ "high" ];
    };
    # paired with a one-survivor control under the SAME options, so an options step that refused
    # `unique` itself reads red here rather than as the refusal this cell asserts.
    test-unique-two-survivors-refused-catchably = {
      expr =
        map
          (
            rules:
            (builtins.tryEval (
              builtins.deepSeq (uRun {
                exclusive = true;
                unique = true;
              } rules) null
            )).success
          )
          [
            [
              (uMk "a" 5)
              (uMk "b" 5)
            ]
            [
              (uMk "a" 5)
              (uMk "b" 0)
            ]
          ];
      expected = [
        false
        true
      ];
    };
    test-unique-unset-tie-fires-additively = {
      expr =
        map (a: a.v)
          (uRun { } [
            (uMk "a" 5)
            (uMk "b" 5)
          ]).actions.default;
      expected = [
        "a"
        "b"
      ];
    };
  };
}
