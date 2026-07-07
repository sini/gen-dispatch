{ prelude }:
let
  mkActions =
    groups:
    let
      tagToGroup = prelude.foldl' (
        acc: groupName: prelude.foldl' (acc': tag: acc' // { ${tag} = groupName; }) acc groups.${groupName}
      ) { } (builtins.attrNames groups);

      constructors = prelude.foldl' (
        acc: groupName:
        prelude.foldl' (
          acc': tag: acc' // { ${tag} = args: { __action = tag; } // args; }
        ) acc groups.${groupName}
      ) { } (builtins.attrNames groups);

      classify =
        action:
        if tagToGroup ? ${action.__action} then
          tagToGroup.${action.__action}
        else
          throw "gen-dispatch: unknown action tag '${action.__action}'";
    in
    constructors // { inherit classify; };
in
{
  inherit mkActions;
}
