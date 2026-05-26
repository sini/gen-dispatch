{ lib, deriveLib, selectLib, genPure, ... }:
let
  inherit (deriveLib) fixpoint fromFunction fromFunctionMatch mkRule mkActions
    entryAnywhere entryAfter override;
  mkI = genPure.mkIntensional;
  sel = selectLib;
  adapter = deriveLib.adapters.select;
in
{
  integration = {
    # Den-like scenario: 3 phases, enrichment convergence, override
    test-den-like-scenario = {
      expr = let
        fx = mkActions {
          structural = [ "spawn" "enrich" ];
          resolution = [ "edge" ];
          collection = [ "gather" ];
        };

        rules = [
          # Structural: enriches context with isNixos
          (mkRule {
            condition = { host = false; };
            produce = _id: ctx: [
              (fx.enrich { key = "isNixos"; value = true; })
              (fx.spawn { kind = "user"; })
            ];
            identity = "host-init";
          })
          # Resolution: fires after enrichment adds isNixos
          (mkRule {
            condition = { host = false; isNixos = false; };
            produce = _id: _ctx: [ (fx.edge { target = "logging"; }) ];
            identity = "nixos-edges";
          })
          # Collection: fires when host is present
          (mkRule {
            condition = { host = false; };
            produce = _id: _ctx: [ (fx.gather { scope = "all"; }) ];
            identity = "collect-all";
          })
        ];

        r = fixpoint {
          inherit rules;
          context = { host = { name = "igloo"; }; };
          match = fromFunctionMatch;
          classify = fx.classify;
          phases = {
            structural = entryAnywhere {};
            resolution = entryAfter [ "structural" ] {};
            collection = entryAfter [ "resolution" ] {};
          };
          extract = actions:
            lib.foldl' (acc: a:
              if a.__action == "enrich" then acc // { ${a.key} = a.value; } else acc
            ) {} (actions.structural or []);
          combine = ctx: ext: ctx // ext;
          eq = a: b: builtins.attrNames a == builtins.attrNames b;
        };
      in {
        inherit (r) iterations;
        phases = builtins.sort builtins.lessThan (builtins.attrNames r.actions);
        structuralCount = builtins.length (r.actions.structural or []);
        resolutionCount = builtins.length (r.actions.resolution or []);
        collectionCount = builtins.length (r.actions.collection or []);
      };
      expected = {
        iterations = 2;
        phases = [ "collection" "resolution" "structural" ];
        structuralCount = 2;
        resolutionCount = 1;
        collectionCount = 1;
      };
    };

    # gen-select adapter scenario
    test-selector-conditions = {
      expr = let
        fx = mkActions { default = [ "act" ]; };
        match = adapter.mkMatch selectLib;
        mockCtx = {
          data = id: {
            "host:web" = { type = "host"; env = "prod"; };
            "host:db" = { type = "host"; env = "staging"; };
          }.${id};
          parent = _: null;
          children = _: [];
          ancestors = _: [];
          siblings = _: [];
        };
        r = deriveLib.dispatch {
          rules = [
            (mkRule {
              condition = sel.attrs { type = "host"; env = "prod"; };
              produce = _id: _ctx: [ (fx.act { v = "prod-only"; }) ];
              identity = "prod-rule";
            })
          ];
          id = "host:web";
          context = mockCtx;
          inherit match;
          classify = fx.classify;
          phases = { default = entryAnywhere {}; };
        };
      in r.actions.default;
      expected = [ { __action = "act"; v = "prod-only"; } ];
    };

    # Override + fixpoint integration
    test-override-in-fixpoint = {
      expr = let
        fx = mkActions { default = [ "act" ]; };

        baseRule = mkRule {
          condition = { host = false; };
          produce = _id: _ctx: [ (fx.act { v = "base"; }) ];
          identity = "base";
        };
        customRule = override baseRule (mkRule {
          condition = { host = false; };
          produce = _id: _ctx: [ (fx.act { v = "custom"; }) ];
          identity = "custom";
        });

        r = fixpoint {
          rules = [ baseRule customRule ];
          context = { host = {}; };
          match = fromFunctionMatch;
          classify = fx.classify;
          phases = { default = entryAnywhere {}; };
          extract = _: {};
          combine = ctx: _: ctx;
          eq = _: _: true;
        };
      in map (a: a.v) (r.actions.default or []);
      expected = [ "custom" ];
    };
  };
}
