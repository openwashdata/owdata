# Harvest architecture and design notes

This directory holds the harvest orchestration. The pure parsing and
policy functions it uses live in `R/` (see below for why).

## Files

- `harvest.R`: orchestrator. Enumerate repos, detect data packages,
  parse metadata, assign tiers, assemble the catalog, run gates, write
  all outputs.
- `harvest_helpers.R`: the two interchangeable backends (local clones
  and GitHub API plus raw fetches) behind one source interface.
- `tier_overrides.csv`: escape hatch for misclassified packages. Kept
  near-empty by design.
- `exclude_repos.csv`: denylist backstop for non-package repos. The
  positive detection rule (root DESCRIPTION with a Package field plus at
  least one `data/*.rda`) already excludes these; the file is a backstop.
- `dictionary.csv`: owdata's own variable dictionary, describing the
  three exported tables (the washr convention, dogfooded).
- `packages.json`: generated draft of the r-universe registry.
  Regenerated on every harvest so the two artifacts cannot drift; washr
  and owdata are hard-coded into the generation and asserted by a unit
  test, because the custom registry supersedes the auto-generated one
  and must never drop washr.
- `harvest_report.md`: generated run report with problems and deltas
  against the previous committed run.

## Running a harvest

```sh
# Full harvest from the GitHub organization (used by the weekly workflow;
# needs GITHUB_TOKEN or GITHUB_PAT for the API budget):
OWD_HARVEST_BACKEND=github Rscript data-raw/harvest.R

# Identical parsing against local clones (offline development and the
# initial seed; GitHub-API-only columns come back NA):
OWD_HARVEST_BACKEND=local OWD_LOCAL_ROOT=~/path/to/clones Rscript data-raw/harvest.R
```

After a harvest, regenerate docs and run the gate:

```sh
Rscript -e 'roxygen2::roxygenise()'
Rscript -e 'testthat::test_local(stop_on_failure = TRUE)'
```

## Error tolerance and gates

Per-repo failures never abort the run; they accumulate in a problems
table written to `harvest_report.md`. The run exits non-zero only when a
shipped table would be empty or more than 10 percent of detected
packages failed to parse. On top of the schema tests, the report lists
deltas against the previous committed run (NA-rate increases in key
columns, tier changes, dropped packages) so silent degradation shows up
as a diff, not as silence.

## Deviations from the original plan issues

Two deliberate deviations from the issue specs, both forced by making
`devtools::check()` pass:

1. The plan named both data objects `owd_packages` and accessor
   functions `owd_packages()`. A lazy-data object and an exported
   function cannot share a name in one package, so the tables ship as
   one internal object (`R/sysdata.rda`) and the accessors are the only
   API. This also lets the accessors serve a refreshed catalog from
   `owd_refresh()` transparently.
2. The plan placed parsers and tier logic in `data-raw/`, but their unit
   tests must run during `R CMD check` of the built tarball, which does
   not contain `data-raw/`. The pure functions therefore live in
   `R/parsers.R` and `R/tier_policy.R` (internal, tested), while
   everything that touches the network or filesystem stays here.

## Seed harvest

The initial catalog was produced with the local backend over shallow
clones of the public repositories listed in the organization
spreadsheet (54 repos; three further repos are private and will enter
the catalog with the first workflow harvest, which enumerates the org
via the API). Columns only the GitHub API can supply (created_at,
topics, latest_release) are NA until that first automated run.
