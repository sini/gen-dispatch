{
  lib,
  genDispatch,
  ...
}:
let
  inherit (genDispatch)
    restrict
    override
    chain
    mkRule
    ;
in
{
  flake.tests.compose = {
    test-restrict-shape = {
      expr =
        let
          base =
            mkRule
              {
                identity = "base";
                nac = "original-nac";
              }
              {
                host = false;
              }
              (_id: _ctx: [ ]);
          restricted = restrict { env = false; } base;
        in
        {
          isRestricted = restricted.condition.__restricted or false;
          original = restricted.condition.original;
          extra = restricted.condition.extra;
          nac = restricted.nac;
          identity = restricted.identity;
        };
      expected = {
        isRestricted = true;
        original = {
          host = false;
        };
        extra = {
          env = false;
        };
        nac = "original-nac";
        identity = "restricted:base";
      };
    };

    test-restrict-anonymous = {
      expr =
        let
          base = mkRule { } {
            host = false;
          } (_id: _ctx: [ ]);
          restricted = restrict { env = false; } base;
        in
        restricted.identity;
      expected = null;
    };

    test-override-appends = {
      expr =
        let
          original = mkRule {
            identity = "original";
          } { } (_id: _ctx: [ ]);
          replacement = mkRule {
            identity = "replacement";
          } { } (_id: _ctx: [ ]);
          result = override { inherit original replacement; };
        in
        result.overrides;
      expected = [ "original" ];
    };

    test-override-anonymous-throws = {
      expr = builtins.tryEval (override {
        original = mkRule { } { } (_id: _ctx: [ ]);
        replacement = mkRule { identity = "rep"; } { } (_id: _ctx: [ ]);
      });
      expected = {
        success = false;
        value = false;
      };
    };

    test-chain-identity = {
      expr =
        let
          a = mkRule {
            identity = "a";
          } { } (_id: _ctx: [ ]);
          b = mkRule {
            identity = "b";
          } { } (_id: _ctx: [ ]);
          chained = chain (_: { }) a b;
        in
        chained.identity;
      expected = "chain:a:b";
    };

    # A composite is anonymous the moment ANY of its arms is: the arm with no identity
    # is the one whose distinct rules the handle can no longer tell apart. The retired
    # "anon" default gave two behaviourally distinct composites ONE handle, which
    # `override` then accepted precisely because it was non-null.
    test-chain-anonymous = {
      expr =
        let
          a = mkRule { } { } (_id: _ctx: [ ]);
          b = mkRule { } { } (_id: _ctx: [ ]);
          chained = chain (_: { }) a b;
        in
        chained.identity;
      expected = null;
    };

    # The MIXED pair is what forces the either-arm scope rather than the anonymous one:
    # a rule propagating null only when BOTH arms are anonymous still collides these two.
    test-chain-mixed-identified-and-anonymous = {
      expr =
        let
          identified = mkRule {
            identity = "a";
          } { } (_id: _ctx: [ ]);
          anonymous = mkRule { } { } (_id: _ctx: [ ]);
        in
        (chain (_: { }) identified anonymous).identity;
      expected = null;
    };
  };
}
