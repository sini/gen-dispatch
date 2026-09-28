{ lib, genDispatch, ... }:
let
  inherit (genDispatch)
    mkRule
    mkActions
    dispatch
    fromFunctionMatch
    groupOf
    producesOf
    deriveGroup
    ;
  fx = mkActions {
    structural = [
      "spawn"
      "enrich"
    ];
    resolution = [
      "edge"
      "drop"
    ];
    collection = [ "gather" ];
  };
  match = fromFunctionMatch;
in
{
  flake.tests.declared = {
    # --- readers: the declared stratum is read WITHOUT firing `produce` ---------------------

    # groupOf/producesOf read the declaration off the rule value. The `produce` body THROWS if
    # fired: the readers must return the declared data anyway (fire-and-observe would blow up).
    test-groupOf-reads-without-firing = {
      expr =
        let
          r = mkRule {
            group = "resolution";
            produces = [ "edge" ];
          } { } (_: _: throw "produce fired — the reader must NOT fire");
        in
        {
          g = groupOf r;
          p = producesOf r;
        };
      expected = {
        g = "resolution";
        p = [ "edge" ];
      };
    };

    # An undeclared rule (no `group`, no `produces`) reads null on both — the infer-as-before signal.
    test-readers-undeclared-null = {
      expr =
        let
          r = mkRule { } { } (_: _: [ ]);
        in
        {
          g = groupOf r;
          p = producesOf r;
        };
      expected = {
        g = null;
        p = null;
      };
    };

    # --- mkActions.groupOfKind: classify a bare KIND/tag (no action value) ------------------

    test-groupOfKind-classifies = {
      expr = {
        s = fx.groupOfKind "spawn";
        r = fx.groupOfKind "edge";
        c = fx.groupOfKind "gather";
      };
      expected = {
        s = "structural";
        r = "resolution";
        c = "collection";
      };
    };

    test-groupOfKind-unknown-throws = {
      expr = builtins.tryEval (fx.groupOfKind "nope");
      expected = {
        success = false;
        value = false;
      };
    };

    # --- deriveGroup: definition-time stratum authority (classifies declared kinds) ---------

    # A rule declaring only its produced-kind family gets its `group` DERIVED from the kinds —
    # no `produce` fired. `produce` throws to prove derivation is by classification, not probe.
    test-deriveGroup-derives-from-produces = {
      expr =
        let
          r = deriveGroup fx.groupOfKind (
            mkRule {
              produces = [ "edge" ];
              identity = "r";
            } { } (_: _: throw "produce fired — deriveGroup must classify, not probe")
          );
        in
        groupOf r;
      expected = "resolution";
    };

    # A multi-kind family that classifies to ONE group derives that group.
    test-deriveGroup-multi-kind-same-group = {
      expr =
        let
          r = deriveGroup fx.groupOfKind (
            mkRule {
              produces = [
                "edge"
                "drop"
              ];
              identity = "r";
            } { } (_: _: [ ])
          );
        in
        groupOf r;
      expected = "resolution";
    };

    # An explicit `group` that AGREES with the classified stratum is preserved (no throw).
    test-deriveGroup-honors-agreeing-explicit = {
      expr =
        let
          r = deriveGroup fx.groupOfKind (
            mkRule {
              group = "resolution";
              produces = [ "edge" ];
              identity = "r";
            } { } (_: _: [ ])
          );
        in
        groupOf r;
      expected = "resolution";
    };

    # CONFLICT: an explicit `group` that disagrees with the declared kinds' stratum aborts NAMED.
    test-deriveGroup-conflict-throws = {
      expr = builtins.tryEval (
        builtins.deepSeq (deriveGroup fx.groupOfKind (
          mkRule {
            group = "structural";
            produces = [ "edge" ];
            identity = "misdeclared";
          } { } (_: _: [ ])
        )) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    # Declared kinds SPANNING more than one group violate single-group-per-rule at DEFINITION time.
    test-deriveGroup-spanning-throws = {
      expr = builtins.tryEval (
        builtins.deepSeq (deriveGroup fx.groupOfKind (
          mkRule {
            produces = [
              "spawn"
              "edge"
            ];
            identity = "spanning";
          } { } (_: _: [ ])
        )) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    # An unknown declared kind aborts at definition time (via groupOfKind's throw).
    test-deriveGroup-unknown-kind-throws = {
      expr = builtins.tryEval (
        builtins.deepSeq (deriveGroup fx.groupOfKind (
          mkRule {
            produces = [ "bogus" ];
            identity = "typo";
          } { } (_: _: [ ])
        )) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    # The same refusal at DEFINITION, not at use: forcing the derived rule to WHNF (`seq`, no
    # `deepSeq`, no `.group` read) already refuses for ONE unknown kind, and `tryEval` catches it.
    test-deriveGroup-single-unknown-kind-refuses-at-whnf = {
      expr = builtins.tryEval (
        builtins.seq (deriveGroup fx.groupOfKind (
          mkRule {
            produces = [ "bogus" ];
            identity = "typo";
          } { } (_: _: [ ])
        )) true
      );
      expected = {
        success = false;
        value = false;
      };
    };

    # Undeclared rule (produces = null) is a no-op: deriveGroup returns it unchanged.
    test-deriveGroup-undeclared-noop = {
      expr =
        let
          r = mkRule {
            group = "structural";
          } { } (_: _: [ ]);
        in
        groupOf (deriveGroup fx.groupOfKind r) == "structural"
        && producesOf (deriveGroup fx.groupOfKind r) == null;
      expected = true;
    };

    # --- dispatch HONORS the declaration: it partitions by the declared stratum -------------

    # A deriveGroup-built rule dispatches into its DERIVED stratum in a multi-group run, with no
    # `group` written by hand — the declaration alone routes it.
    test-dispatch-declared-lands-in-stratum = {
      expr =
        let
          r = deriveGroup fx.groupOfKind (
            mkRule
              {
                produces = [ "edge" ];
                identity = "r";
              }
              {
                host = false;
              }
              (_: _: [ (fx.edge { }) ])
          );
          res = dispatch { } {
            rules = [ r ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = fx.classify;
            groupOrder = [
              "structural"
              "resolution"
            ];
          };
        in
        {
          groups = res.orderedGroups;
          n = builtins.length (res.actions.resolution or [ ]);
        };
      expected = {
        groups = [ "resolution" ];
        n = 1;
      };
    };

    # dispatch SKIPS the fire-and-classify inference for a declared rule: with a THROWING
    # `classify`, a multi-group run forces the classify-validation (`head actionGroups == group`)
    # for undeclared rules — but a declared rule never invokes classify on its actions, so it
    # dispatches cleanly (the contrast is `test-dispatch-undeclared-still-validates`).
    test-dispatch-declared-skips-classify = {
      expr =
        let
          r =
            mkRule
              {
                group = "resolution";
                produces = [ "edge" ];
                identity = "declared";
              }
              {
                host = false;
              }
              (_: _: [ (fx.edge { }) ]);
          res = dispatch { } {
            rules = [ r ];
            id = "x";
            context = {
              host = { };
            };
            inherit match;
            classify = _: throw "classify called — declared rule must skip inference";
            groupOrder = [
              "structural"
              "resolution"
            ];
          };
        in
        builtins.length (res.actions.resolution or [ ]);
      expected = 1;
    };

    # Back-compat contrast: the SAME multi-group run with an UNDECLARED rule (produces = null)
    # still runs the inference — the throwing classify is forced by the declared-group check and
    # the dispatch aborts. Proves the skip above is real, and the classify path is unchanged.
    test-dispatch-undeclared-still-validates = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch { } {
          rules = [
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
          classify = _: throw "classify called";
          groupOrder = [
            "structural"
            "resolution"
          ];
        }) true
      );
      expected = {
        success = false;
        value = false;
      };
    };
  };
}
