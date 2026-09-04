# owdata design decisions, 2026-09-04

Status: decided by the maintainer, who is the only maintainer. This file
replaces the version-tier policy, the premortem sign-off step and the
dated update sections in the issues. Guiding rule: as slim as the job
needs, nothing speculative.

Inputs: the design review of the same date (issues #1 to #16, the
premortem of 2026-07-18, the review note of 2026-09-04, PR #15 and the
seed data it ships).

## 1. Inclusion: two flags, no tiers

- `published`: TRUE when CITATION.cff carries a Zenodo DOI
  (10.5281/zenodo.*). This is what the organisation has always meant by
  published.
- `reviewed`: NA for now. Filled from pkgreview (the closed review
  issues) once that check is worth wiring; until then the column exists
  so the schema never changes.
- Every detected package is listed in `owd_packages`. Dataset and
  variable detail is harvested for published packages only.
- Version numbers carry no policy meaning. No dev/candidate/catalogued
  tiers, no grandfather rule, no `legacy` flag, no `tier_overrides.csv`,
  no migration campaign. `exclude_repos.csv` stays as the denylist.

Why: the seed harvest classified 30 packages as catalogued, 27 of them
through the transitional rule and 3 of those at version 0.0.0.9000. A
rule that is 90 percent exception is the wrong rule. The 45-review
campaign that would have retired it has no capacity behind it.

Effect on issues: #2 and #10 close. The versioning-policy article
becomes one paragraph in the README: publish with washr, mint the DOI,
the harvest lists you within a week.

## 2. Distribution: snapshot in the package, weekly version bump

- The tables ship as the internal object `owd_catalog` in
  `R/sysdata.rda` behind the accessors. This also resolves the name
  collision in #1, #5 and #6: a lazydata object and an exported function
  cannot both be called `owd_packages`.
- Each harvest that changes data bumps the fourth version component and
  sets `Date`, so r-universe rebuilds and `update.packages()` sees it.
- No `owd_refresh()`, no user cache, no runtime network code. The
  startup message states the harvest date; that is the staleness signal.

Effect on issues: #6 loses the refresh decision; #5 loses the refresh
paragraph; #9 keeps the bump.

## 3. Site: the catalog renders on openwashdata.org only

- The website's data page reads `inst/extdata/owd_packages.csv` and
  `owd_variables.csv` from this repository's main branch and renders the
  DT tables it already has. That switch closes washr #69.
- owdata's own pkgdown site is reference documentation only, written by
  `washr::setup_website()` and `washr::use_brand()`. No catalog,
  datasets or variables articles.

Effect on issues: #7 shrinks to "reference site via washr"; #11 owns the
website change and is the launch criterion; the variable search lives on
openwashdata.org.

## 4. Install: r-universe, registry committed by hand

- `owd_install()` wraps `install.packages()` against
  openwashdata.r-universe.dev with CRAN as fallback, as in PR #15.
- The registry lists published packages plus washr and owdata. The
  harvest regenerates `data-raw/packages.json`; the harvest report says
  when it differs from the last committed copy; the maintainer commits it
  to the registry repository by hand. Packages get published a few times
  a year, so this is minutes per year.
- No org PAT, no sync step.

Effect on issues: #8 keeps the registry mechanics and the washr warning;
#9 drops the sync step and the PAT.

## 5. Automation: the harvest opens a pull request

- Weekly cron plus `workflow_dispatch`. The job runs the harvest, runs
  roxygen and the tests as the gate, then opens or updates one pull
  request with the generated files. The maintainer merges it.
- The built-in token is enough. Known limit: a pull request opened with
  that token triggers no `pull_request` workflows, so the checks that
  matter run inside the harvest job itself, and R-CMD-check and pkgdown
  run on main after the merge (a merge by a person is a normal push).
  Consequence for branch protection: do not make R-CMD-check a required
  status on main, or the harvest PR can never merge.
- Failure surfacing: the job fails visibly in the Actions tab and the
  PR is not opened. No harvest-failure issue automation.

Effect on issues: #9 is rewritten around the PR flow.

## 6. Outputs of a harvest

- `R/sysdata.rda` (internal snapshot), `inst/extdata/owd_packages.csv`,
  `owd_datasets.csv`, `owd_variables.csv`, `data-raw/packages.json`,
  `data-raw/harvest_report.md`.
- No xlsx, no catalog.json, no `owd_files` table. The website and the
  package read the same CSVs.
- The harvest must run in a UTF-8 locale. PR #15's seed data carries
  `<U+00F6>` escapes in 37 places because its container did not. The
  test gate asserts no such escapes and no duplicated DOI across
  packages, so a value-level defect cannot ship on green.

Effect on issues: #5 loses xlsx, catalog.json and the files table; the
`keywords`, `spatial_coverage` and `temporal_coverage` columns stay
because the website already shows them.

## 7. Repository: main only, three PRs closed

- Pull requests #13, #14 and #15 close. The branch of #15 stays as a
  parts bin: parsers, fixtures, harvest backends, workflows, the
  upstream fix list and the seed data are worth porting piece by piece.
- Human work is a branch and a pull request to main. No `dev` branch.
- The scaffold is made by hand with washr 1.1.0 per #1, and the
  workflows are committed by a person in the first commit, since session
  tokens cannot write `.github/workflows/`.

## 8. Tooling: one CLAUDE.md

- One short file: purpose, layout, the commands, the branch rule, the
  dependency rule (base R plus the declared Imports under `R/`), the
  style rules, which files are generated. No recorded skill list, no
  hooks, no settings allowlist.

Effect on issues: #16 shrinks to the owdata CLAUDE.md; the washr half
moves to washr if wanted.

## Open question

The issues say about 70 packages; the GitHub harvest found 54. If the
gap is private repositories, the built-in token cannot see them and they
stay out of the catalog by construction. Check once, record the answer
in `exclude_repos.csv` or the README, and stop counting to 70.

## Resulting plan

1. #1 scaffold with washr 1.1.0, workflows committed by hand, CLAUDE.md.
2. #3 parsers and fixtures, ported from PR #15, plus desc and cffr where
   they replace regexes.
3. #4 harvest with the two backends, the published flag, UTF-8 and
   duplicate-DOI gates, the version bump, the registry draft.
4. #5 data model: `owd_packages`, `owd_datasets`, `owd_variables` as
   above.
5. #6 exports: `owd_packages()`, `owd_datasets()`, `owd_variables()`,
   `owd_search()`, `owd_install()`, the startup message.
6. #9 harvest workflow that opens a pull request.
7. #8 registry repository with the first `packages.json`.
8. #11 website reads the CSVs; washr #69 closes.

Closed by this file: #2, #7 (as written), #10. Trimmed: #5, #6, #8, #9,
#11, #16. #12 is rewritten to the list above.
