# Declared-stratum rule vocabulary — a rule DECLARES its dispatch stratum (`group`) and its
# produced-kind FAMILY (`produces`) as DATA, so a consumer READS the stratum instead of FIRING
# `produce` on a sentinel to observe which stratum the actions land in. In Datalog stratification
# (Arntzenius & Krishnaswami 2016) a rule's stratum is a STATIC property discharged by analysis of
# the predicates it derives, not by running the rule; this is the gen-dispatch analog of gen-resolve's
# per-equation `stratum` field (`gen-resolve/lib/schedule.nix`), where each equation names its stratum
# up front and `scheduleWith { strataOrder }` reads it. Here the stratum is discharged by CLASSIFYING
# the declared produced kinds — the same `classify`/`mkActions` kind→group map dispatch already uses —
# so it needs no fire-and-observe probe. The group NAMES are shared with gen-resolve's `strataOrder`
# (`structural`, `resolution`, …), keeping the two schedules compatible.
{ prelude }:
let
  ruleName = r: if (r.identity or null) != null then r.identity else "anonymous";

  # Read the declared stratum off a rule WITHOUT firing `produce`. `null` = undeclared (a consumer
  # falls back to inference for these — e.g. gen-dispatch's own fire-and-classify validation).
  groupOf = r: r.group or null;

  # Read the declared produced-kind family off a rule WITHOUT firing. `null` = undeclared.
  producesOf = r: r.produces or null;

  # `deriveGroup classifyKind rule` — the DEFINITION-TIME stratum authority. It classifies the rule's
  # declared `produces` (a list of kind tags) through `classifyKind : tag -> group` and STAMPS the
  # resulting `group` on the rule, so `dispatch` partitions the rule by the declaration and never
  # fires `produce` to learn its stratum. The single-group-per-rule law (gen-dispatch's core invariant)
  # is discharged HERE, at definition time, rather than at fire time:
  #   • declared kinds spanning more than one group abort NAMED (the rule cannot occupy two strata);
  #   • an explicit `group` that disagrees with the classified stratum aborts NAMED — the declared-
  #     stratum / produced-kind CONFLICT (the static analog of dispatch's runtime "declared group X
  #     but produced Y actions" throw, but caught before any body runs).
  # A rule without `produces` (declared = null) is returned UNCHANGED: undeclared means "infer as
  # before", so the vocabulary is additive and back-compatible. An unknown declared kind aborts here
  # too, via `classifyKind`'s own throw (a typo in `produces` fails at definition, not silently).
  # Every declared kind is classified BEFORE the rule is returned: `unique` compares elements only
  # when there are two or more, so for a ONE-kind family nothing else would force the classification
  # and the throw would surface only when `group` is read.
  deriveGroup =
    classifyKind: r:
    let
      produces = r.produces or null;
    in
    if produces == null then
      r
    else
      let
        classified = map classifyKind produces;
        groups = prelude.unique classified;
      in
      builtins.deepSeq classified (
        if builtins.length groups > 1 then
          throw "gen-dispatch: rule \"${ruleName r}\" declares kinds spanning multiple groups: ${builtins.concatStringsSep ", " groups} (single-group-per-rule)"
        else
          let
            g = if groups == [ ] then null else builtins.head groups;
          in
          if r.group != null && g != null && r.group != g then
            throw "gen-dispatch: rule \"${ruleName r}\" declares group \"${r.group}\" but its produced kinds classify to \"${g}\""
          else
            r // { group = if g != null then g else r.group; }
      );
in
{
  inherit groupOf producesOf deriveGroup;
}
