{
  lib,
  genDerive,
  mkIntensional,
  ...
}:
let
  inherit (genDerive)
    fixpoint
    fromFunction
    fromFunctionMatch
    mkRule
    mkActions
    entryAnywhere
    entryAfter
    ;
  mkI = mkIntensional;
  fx = mkActions {
    default = [
      "enrich"
      "act"
    ];
  };
  match = fromFunctionMatch;
  phases = {
    default = entryAnywhere { };
  };

  extract =
    actions:
    lib.foldl' (acc: a: if a.__action == "enrich" then acc // { ${a.key} = a.value; } else acc) { } (
      actions.default or [ ]
    );
  combine = ctx: extracted: ctx // extracted;
  eq = a: b: builtins.attrNames a == builtins.attrNames b;
in
{
  flake.tests.fixpoint = {
    test-converge-one-iteration = {
      expr =
        let
          r = fixpoint {
            rules = [ (fromFunction ({ host, ... }: [ (fx.act { v = 1; }) ])) ];
            context = {
              host = { };
            };
            inherit
              match
              phases
              extract
              combine
              eq
              ;
            classify = fx.classify;
          };
        in
        {
          inherit (r) iterations;
          actionCount = builtins.length (r.actions.default or [ ]);
        };
      expected = {
        iterations = 1;
        actionCount = 1;
      };
    };

    test-converge-two-iterations = {
      expr =
        let
          r = fixpoint {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [
                  (fx.enrich {
                    key = "isNixos";
                    value = true;
                  })
                ];
                identity = "enricher";
              })
              (mkRule {
                condition = {
                  host = false;
                  isNixos = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "platform"; }) ];
                identity = "consumer";
              })
            ];
            context = {
              host = { };
            };
            inherit
              match
              phases
              extract
              combine
              eq
              ;
            classify = fx.classify;
          };
        in
        r.iterations;
      expected = 2;
    };

    test-maxiter-cap = {
      expr = builtins.tryEval (
        builtins.deepSeq (fixpoint {
          rules = [
            (fromFunction (
              { host, ... }:
              [
                (fx.enrich {
                  key = "k";
                  value = true;
                })
              ]
            ))
          ];
          context = {
            host = { };
          };
          inherit match phases;
          classify = fx.classify;
          extract = _: {
            newKey = true;
          };
          combine = ctx: ext: ctx // ext;
          eq = _a: _b: false;
          maxIter = 3;
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    test-identified-fires-once = {
      expr =
        let
          r = fixpoint {
            rules = [
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [ (fx.act { v = "once"; }) ];
                identity = "single-fire";
              })
            ];
            context = {
              host = { };
            };
            inherit
              match
              phases
              extract
              combine
              ;
            classify = fx.classify;
            eq = _: _: true;
          };
        in
        builtins.length (r.actions.default or [ ]);
      expected = 1;
    };

    test-anonymous-refires-each-iteration = {
      expr =
        let
          r = fixpoint {
            rules = [
              # Identified: enriches context once (fires iteration 1 only)
              (mkRule {
                condition = {
                  host = false;
                };
                produce = _id: _ctx: [
                  (fx.enrich {
                    key = "isNixos";
                    value = true;
                  })
                ];
                identity = "enricher";
              })
              # Anonymous: fires EVERY iteration it matches
              (fromFunction ({ host, ... }: [ (fx.act { v = "anon"; }) ]))
            ];
            context = {
              host = { };
            };
            inherit
              match
              phases
              extract
              combine
              eq
              ;
            classify = fx.classify;
          };
          # 2 iterations: enricher adds isNixos, stabilizes on iter 2
          # Anonymous fires both iterations → 2 act actions
          # Enricher fires once → 1 enrich action
        in
        builtins.length (r.actions.default or [ ]);
      expected = 3; # iter1: enrich + act; iter2: act
    };

    test-stratified-single-pass = {
      expr =
        let
          fx = mkActions {
            structural = [ "spawn" ];
            resolution = [ "edge" ];
          };
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
              identity = "e";
            })
          ];
          r = fixpoint {
            inherit rules;
            context = {
              host = { };
            };
            match = fromFunctionMatch;
            classify = fx.classify;
            phases = {
              structural = entryAnywhere { };
              resolution = entryAfter [ "structural" ] { };
            };
            extract = actions: if (actions.structural or [ ]) != [ ] then { flag = true; } else { };
            combine = ctx: ext: ctx // ext;
            eq = a: b: builtins.attrNames a == builtins.attrNames b;
          };
        in
        {
          iters = r.iterations;
          edges = builtins.length (r.actions.resolution or [ ]);
        };
      # The edge fires WITHIN pass 1 (stratified threading). iterations is 2 because
      # fixpoint's `eq` compares pre- vs post-threading context: pass 1 changes the
      # context, so a second pass confirms convergence.
      expected = {
        iters = 2;
        edges = 1;
      };
    };
  };
}
