# THE gen-dispatch × gen-select PAIRING — `adapters.select` bridges dispatch conditions to
# gen-select's selector algebra (`mkMatch`, `selectorSpecificity`), and testing that bridge means
# evaluating it against a REAL gen-select, not a mock. Its home is this ci: it is the one node that
# already reaches both subjects (this tree by relative path, gen-select through the test-plane pin
# `integration.nix` uses), and gen-select does not reach this ci back, so the relock settles it in
# one pass. A ci input is a TEST dependency (ADR-0037): the library's own graph — the core tier,
# gen-select-free by construction — is untouched. Moved verbatim from gen-harness's ci, where the
# same two pins closed a revision cycle through every member's harness pin
# (den-hoag-lock-currency-ruling-ez1yq).

{
  lib,
  genDispatch,
  genSelect,
  ...
}:
let
  sel = genSelect;
  adapter = genDispatch.adapters.select;
  match = adapter.mkMatch genSelect;
  mockCtx = {
    data =
      id:
      {
        "host:web" = {
          type = "host";
          env = "prod";
        };
        "user:tux" = {
          type = "user";
        };
      }
      .${id};
    parent = id: { "user:tux" = "host:web"; }.${id} or null;
    children = id: { "host:web" = [ "user:tux" ]; }.${id} or [ ];
    ancestors = id: { "user:tux" = [ "host:web" ]; }.${id} or [ ];
    siblings = _: [ ];
  };
in
{
  flake.tests.dispatch-select-adapter = {
    test-match-attrs = {
      expr = match (sel.attrs { type = "host"; }) "host:web" mockCtx;
      expected = true;
    };

    test-match-attrs-no-match = {
      expr = match (sel.attrs { type = "user"; }) "host:web" mockCtx;
      expected = false;
    };

    test-match-restricted = {
      expr = match {
        __restricted = true;
        original = sel.attrs { type = "host"; };
        extra = sel.attrs { env = "prod"; };
      } "host:web" mockCtx;
      expected = true;
    };

    test-match-restricted-fails = {
      expr = match {
        __restricted = true;
        original = sel.attrs { type = "host"; };
        extra = sel.attrs { env = "staging"; };
      } "host:web" mockCtx;
      expected = false;
    };

    test-specificity-attrs = {
      expr = adapter.selectorSpecificity (
        sel.attrs {
          type = "host";
          env = "prod";
        }
      );
      expected = 2;
    };

    test-specificity-star = {
      expr = adapter.selectorSpecificity sel.star;
      expected = 0;
    };

    test-specificity-has = {
      expr = adapter.selectorSpecificity (sel.has (sel.attrs { type = "user"; }));
      expected = 2;
    };

    test-specificity-and = {
      expr = adapter.selectorSpecificity (
        sel.and [
          (sel.attrs { type = "host"; })
          (sel.attrs { env = "prod"; })
        ]
      );
      expected = 2;
    };

    test-specificity-when = {
      expr = adapter.selectorSpecificity (sel.when (_id: _ctx: true));
      expected = 0;
    };
  };
}
