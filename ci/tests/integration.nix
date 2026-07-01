{
  lib,
  genDerive,
  genSelect,
  ...
}:
let
  inherit (genDerive)
    fromFunctionMatch
    mkRule
    mkActions
    override
    ;
  sel = genSelect;
  adapter = genDerive.adapters.select;
in
{
  flake.tests.integration = {
    # Den-like scenario: 3 stratified phases, enrich->resolution cascade threaded
    # phase->phase WITHIN one dispatch pass (via extract/combine). The convergence LOOP
    # that fixpoint used to wrap this now belongs to gen-resolve (gen-scope.circular);
    # the single pass already yields the terminal actions because the cascade is a
    # monotone forward stratum fold — see gen-resolve/spike/gen-derive-loop-step for the
    # byte-identical loop==circular∘dispatch equivalence proof.
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
              phase = "structural";
            })
            # Resolution: fires after enrichment adds isNixos
            (mkRule {
              condition = {
                host = false;
                isNixos = false;
              };
              produce = _id: _ctx: [ (fx.edge { target = "logging"; }) ];
              identity = "nixos-edges";
              phase = "resolution";
            })
            # Collection: fires when host is present
            (mkRule {
              condition = {
                host = false;
              };
              produce = _id: _ctx: [ (fx.gather { scope = "all"; }) ];
              identity = "collect-all";
              phase = "collection";
            })
          ];

          r = genDerive.dispatch {
            inherit rules;
            id = null;
            context = {
              host = {
                name = "igloo";
              };
            };
            match = fromFunctionMatch;
            classify = fx.classify;
            phaseOrder = [
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
          phases = builtins.sort builtins.lessThan (builtins.attrNames r.actions);
          structuralCount = builtins.length (r.actions.structural or [ ]);
          resolutionCount = builtins.length (r.actions.resolution or [ ]);
          collectionCount = builtins.length (r.actions.collection or [ ]);
        };
      expected = {
        phases = [
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
          r = genDerive.dispatch {
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
            phaseOrder = [ "default" ];
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

          r = genDerive.dispatch {
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
            phaseOrder = [ "default" ];
          };
        in
        map (a: a.v) (r.actions.default or [ ]);
      expected = [ "custom" ];
    };
  };
}
