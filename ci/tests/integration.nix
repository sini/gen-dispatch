{
  lib,
  genDispatch,
  genSelect,
  ...
}:
let
  inherit (genDispatch)
    fromFunctionMatch
    mkRule
    mkActions
    override
    ;
  sel = genSelect;
  adapter = genDispatch.adapters.select;
in
{
  flake.tests.integration = {
    # Den-like scenario: 3 stratified groups, enrich->resolution cascade threaded
    # group->group WITHIN one dispatch pass (via extract/combine). The convergence LOOP
    # is gen-resolve's (gen-scope.circular); the single pass already yields the terminal
    # actions because the cascade is a monotone forward stratum fold — and recompute at
    # the fixpoint makes the action set a function of the converged context (confluence).
    test-den-like-scenario = {
      expr =
        let
          fx = mkActions {
            structural = [
              "spawn"
              "enrich"
            ];
            resolution = [ "edge" ];
            collection = [ "gather" ];
          };

          rules = [
            # Structural: enriches context with isNixos
            (mkRule {
              condition = {
                host = false;
              };
              produce = _id: ctx: [
                (fx.enrich {
                  key = "isNixos";
                  value = true;
                })
                (fx.spawn { kind = "user"; })
              ];
              identity = "host-init";
              group = "structural";
            })
            # Resolution: fires after enrichment adds isNixos
            (mkRule {
              condition = {
                host = false;
                isNixos = false;
              };
              produce = _id: _ctx: [ (fx.edge { target = "logging"; }) ];
              identity = "nixos-edges";
              group = "resolution";
            })
            # Collection: fires when host is present
            (mkRule {
              condition = {
                host = false;
              };
              produce = _id: _ctx: [ (fx.gather { scope = "all"; }) ];
              identity = "collect-all";
              group = "collection";
            })
          ];

          r = genDispatch.dispatch {
            inherit rules;
            id = null;
            context = {
              host = {
                name = "igloo";
              };
            };
            match = fromFunctionMatch;
            classify = fx.classify;
            groupOrder = [
              "structural"
              "resolution"
              "collection"
            ];
            extract =
              actions:
              lib.foldl' (acc: a: if a.__action == "enrich" then acc // { ${a.key} = a.value; } else acc) { } (
                actions.structural or [ ]
              );
            combine = ctx: ext: ctx // ext;
          };
        in
        {
          groups = builtins.sort builtins.lessThan (builtins.attrNames r.actions);
          structuralCount = builtins.length (r.actions.structural or [ ]);
          resolutionCount = builtins.length (r.actions.resolution or [ ]);
          collectionCount = builtins.length (r.actions.collection or [ ]);
        };
      expected = {
        groups = [
          "collection"
          "resolution"
          "structural"
        ];
        structuralCount = 2;
        resolutionCount = 1;
        collectionCount = 1;
      };
    };

    # gen-select adapter scenario
    test-selector-conditions = {
      expr =
        let
          fx = mkActions { default = [ "act" ]; };
          match = adapter.mkMatch genSelect;
          mockCtx = {
            data =
              id:
              {
                "host:web" = {
                  type = "host";
                  env = "prod";
                };
                "host:db" = {
                  type = "host";
                  env = "staging";
                };
              }
              .${id};
            parent = _: null;
            children = _: [ ];
            ancestors = _: [ ];
            siblings = _: [ ];
          };
          r = genDispatch.dispatch {
            rules = [
              (mkRule {
                condition = sel.attrs {
                  type = "host";
                  env = "prod";
                };
                produce = _id: _ctx: [ (fx.act { v = "prod-only"; }) ];
                identity = "prod-rule";
              })
            ];
            id = "host:web";
            context = mockCtx;
            inherit match;
            classify = fx.classify;
            groupOrder = [ "default" ];
          };
        in
        r.actions.default;
      expected = [
        {
          __action = "act";
          v = "prod-only";
        }
      ];
    };

    # Override integration (single dispatch — the override suppresses the base rule)
    test-override-in-dispatch = {
      expr =
        let
          fx = mkActions { default = [ "act" ]; };

          baseRule = mkRule {
            condition = {
              host = false;
            };
            produce = _id: _ctx: [ (fx.act { v = "base"; }) ];
            identity = "base";
          };
          customRule = override baseRule (mkRule {
            condition = {
              host = false;
            };
            produce = _id: _ctx: [ (fx.act { v = "custom"; }) ];
            identity = "custom";
          });

          r = genDispatch.dispatch {
            rules = [
              baseRule
              customRule
            ];
            id = null;
            context = {
              host = { };
            };
            match = fromFunctionMatch;
            classify = fx.classify;
            groupOrder = [ "default" ];
          };
        in
        map (a: a.v) (r.actions.default or [ ]);
      expected = [ "custom" ];
    };
  };
}
