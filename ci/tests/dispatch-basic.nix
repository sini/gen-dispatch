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
    mkRule
    ;
  fx = mkActions { default = [ "act" ]; };
  fs = mkActions { structural = [ "spawn" ]; };
  structural =
    rules:
    dispatch { } {
      inherit rules;
      id = null;
      context = {
        host = 1;
      };
      match = fromFunctionMatch;
      inherit (fs) classify;
      groupOrder = [ "structural" ];
    };
  match = fromFunctionMatch;
  groupOrder = [ "default" ];
in
{
  flake.tests.dispatch-basic = {
    test-single-rule-fires = {
      expr =
        let
          r = dispatch { } {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ])) ];
            id = "host:igloo";
            context = {
              host = { };
            };
            inherit match;
            classify = fx.classify;
            inherit groupOrder;
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
          r = dispatch { } {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { }) ])) ];
            id = "x";
            context = { };
            inherit match;
            classify = fx.classify;
            inherit groupOrder;
          };
        in
        r.actions;
      expected = { };
    };

    test-multiple-rules = {
      expr =
        let
          r = dispatch { } {
            rules = [
              (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ]))
              (fromFunction ({ host, ... }: [ (fx.act { v = 2; }) ]))
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

    # a single action is refused catchably (the error plane pins the message)
    test-single-action-refusal-is-catchable = {
      expr =
        let
          a = (structural [ (fromFunction ({ host, ... }: fs.spawn { kind = "a"; })) ]).actions;
        in
        if (builtins.tryEval (builtins.deepSeq a a)).success then "served" else "THROW(catchable)";
      expected = "THROW(catchable)";
    };

    # G5: the context threading never reads the group's actions
    test-single-action-context-read-forces-no-actions = {
      expr =
        (builtins.tryEval (structural [ (fromFunction ({ host, ... }: fs.spawn { kind = "a"; })) ]).context)
        .value;
      expected = {
        host = 1;
      };
    };

    # G6: the check forces the list and no element
    test-produce-check-forces-no-element = {
      expr =
        (builtins.tryEval (
          builtins.length
            (structural [
              (mkRule
                {
                  identity = "decl";
                  produces = [ "spawn" ];
                }
                { host = false; }
                (
                  _: _: [
                    (throw "elem")
                    (fs.spawn { kind = "d"; })
                  ]
                )
              )
            ]).actions.structural
        )).value;
      expected = 2;
    };
  };
}
