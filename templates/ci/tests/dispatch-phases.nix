{ lib, deriveLib, ... }:
let
  inherit (deriveLib) dispatch mkRule fromFunctionMatch mkActions entryAnywhere entryAfter;
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
  dispatch-phases = {
    test-actions-grouped-by-phase = {
      expr =
        let
          r = dispatch {
            rules = [
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.spawn { }) ];
              })
              (mkRule {
                condition = { host = false; };
                produce = _id: _ctx: [ (fx.edge { }) ];
              })
            ];
            id = "x";
            context = { host = { }; };
            inherit match phases;
            classify = fx.classify;
          };
        in
        builtins.attrNames r.actions;
      expected = [ "resolution" "structural" ];
    };

    test-phase-validation-error = {
      expr = builtins.tryEval (
        builtins.deepSeq (dispatch {
          rules = [
            (mkRule {
              condition = { host = false; };
              produce = _id: _ctx: [
                (fx.spawn { })
                (fx.edge { })
              ];
            })
          ];
          id = "x";
          context = { host = { }; };
          inherit match phases;
          classify = fx.classify;
        }) true
      );
      expected = { success = false; value = false; };
    };
  };
}
