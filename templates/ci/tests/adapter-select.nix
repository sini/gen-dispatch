{ lib, deriveLib, selectLib, ... }:
let
  sel = selectLib;
  adapter = deriveLib.adapters.select;
  match = adapter.mkMatch selectLib;
  mockCtx = {
    data = id: {
      "host:web" = { type = "host"; env = "prod"; };
      "user:tux" = { type = "user"; };
    }.${id};
    parent = id: { "user:tux" = "host:web"; }.${id} or null;
    children = id: { "host:web" = [ "user:tux" ]; }.${id} or [];
    ancestors = id: { "user:tux" = [ "host:web" ]; }.${id} or [];
    siblings = _: [];
  };
in
{
  adapter-select = {
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
      expr = adapter.selectorSpecificity (sel.attrs { type = "host"; env = "prod"; });
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
      expr = adapter.selectorSpecificity (sel.and [
        (sel.attrs { type = "host"; })
        (sel.attrs { env = "prod"; })
      ]);
      expected = 2;
    };

    test-specificity-when = {
      expr = adapter.selectorSpecificity (sel.when (_id: _ctx: true));
      expected = 0;
    };
  };
}
