{ prelude }:
let
  mkActions =
    phases:
    let
      tagToPhase = prelude.foldl' (
        acc: phaseName: prelude.foldl' (acc': tag: acc' // { ${tag} = phaseName; }) acc phases.${phaseName}
      ) { } (builtins.attrNames phases);

      constructors = prelude.foldl' (
        acc: phaseName:
        prelude.foldl' (
          acc': tag: acc' // { ${tag} = args: { __action = tag; } // args; }
        ) acc phases.${phaseName}
      ) { } (builtins.attrNames phases);

      classify =
        action:
        if tagToPhase ? ${action.__action} then
          tagToPhase.${action.__action}
        else
          throw "gen-dispatch: unknown action tag '${action.__action}'";
    in
    constructors // { inherit classify; };
in
{
  inherit mkActions;
}
