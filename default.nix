# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-dispatch depends only on gen-prelude; this shim derives it from the pinned
# flake.lock (content-addressed via narHash, so it stays pure) and needs no
# `<nixpkgs>`. Pass `prelude` to override.
{
  prelude ? (
    let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      node = lock.nodes.gen-prelude.locked;
    in
    import "${
      builtins.fetchTree {
        inherit (node)
          type
          owner
          repo
          rev
          narHash
          ;
      }
    }/lib"
  ),
  ...
}:
import ./lib { inherit prelude; }
