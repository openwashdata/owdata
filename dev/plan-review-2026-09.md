# owdata plan review against washr 1.1.0, and Claude skills for R package work

Date: 2026-09-04. Status: review note for the maintainer, no code changes implied. Sources: the twelve owdata issues (#1 to #12, written 2026-07-08, premortem comments 2026-07-18), washr main at 3a3eeba (1.1.0, released 2026-09-02), washr dev, the washr decision documents under dev/, and the open washr issues for v1.2.0.

## 1. What changed in washr since the owdata plan was written

The owdata issues were written on 2026-07-08 against washr 1.0.2. Since then washr shipped 1.1.0 and decided the shape of 1.2.0. The changes that touch owdata:

| washr change | Where | Effect on owdata |
|---|---|---|
| `update_gsheet_metadata()` deleted; the Google Sheet is "not a canonical source"; the catalogue update "becomes org-internal tooling outside the package" (#69 stays open for that replacement) | NEWS 1.1.0, decision document | owdata is that replacement. #11 still says the function "can be soft-deprecated". From 1.1.0 on, no new package writes to the sheet, so the website switchover is no longer a follow-up. |
| Three canonical sources: DESCRIPTION, `data-raw/dictionary.csv`, `CITATION.cff`, plus the file listing of `inst/extdata` | dev/metadata-2026-08/decision-canonical-sources.md | Matches the four inputs of #3 exactly. The parsers read the right files. |
| Keywords, spatial coverage and temporal coverage live in DESCRIPTION as `X-schema.org-keywords`, `X-schema.org-spatialCoverage`, `X-schema.org-temporalCoverage` | Amendment of 2026-09-02, vignette step 5 | #5 uses GitHub topics as a "keyword substitute" and has no location or time columns. The website's sheet already shows `location`, `temporal_coverage` and `keywords`, so the switchover in #11 cannot render the current table without them. |
| `update_metadata()` embeds a schema.org Dataset JSON-LD in every pkgdown page, with `distribution` entries for every file in `inst/extdata` that starts with a dataset name, MIME type from the extension, `.csv.gz` included | R/generate_jsonld.R | #5 hardcodes `csv_url` and `xlsx_url`. Parquet exports are planned for 1.2.0 (#106). The JSON-LD is a second machine-readable source per package, but only for packages that ran the experimental function. |
| `distributions_jsonld()` builds `contentUrl` on the `main` branch | R/generate_jsonld.R line 224 | owdata knows `default_branch` from the API and should use it. washr should too; worth an issue there. |
| `setup_dictionary()` records the first class of multi-class columns (`POSIXct` instead of a deparsed vector) | NEWS 1.1.0 | Packages built before 1.1.0 carry `c("POSIXct", "POSIXt")` in `variable_type`. One more pathology for the #3 fixture list. |
| `setup_ci()` scaffolds R-CMD-check with the `dev` trigger; the review standard requires it | NEWS 1.1.0 | A cheap `has_ci` diagnostic column next to `has_dictionary` and `has_extdata` in #5. |
| `use_brand()` installs `_brand.yml` from openwashdata/brand and wires `_pkgdown.yml` through bslib | NEWS 1.1.0 | #7 copies washmalawi's `_pkgdown.yml` by hand. The brand did not exist when #7 was written. |
| `setup_website()` keeps an existing `_pkgdown.yml`, leaves `docs/` ignored when a pkgdown workflow deploys | NEWS 1.1.0 | owdata deploys through the pkgdown workflow (#1), so washr's own scaffold works for it. |
| Test bar (#75): behavioral test per export, every `expect_error()` names its message, coverage measured in the job summary without Codecov | NEWS 1.1.0, .github/workflows/test-coverage.yaml | The bar owdata's scaffold (#1) should adopt as is. |
| Imports cut from 16 to 10; dplyr, readr, stringr, tibble, dataspice, googlesheets4, lubridate gone; devtools to Suggests | NEWS 1.1.0 | Confirms the "no dplyr in exported code" rule of #6. |
| Engine plus driver decision: washr stays a deterministic R package, a washr skill in the openwashdata plugin drives it (#111, #115); prerequisites are idempotency (#73, shipped), a readiness gate (#82) and cli messaging with real return values (#84), both v1.2.0 | washr #111, #113, #115 | owdata is engine only, which is the right side of that split. The "request catalog inclusion" step of #11 belongs in the guide, the vignette and the skill, not the vignette alone. |
| `check_publication_readiness()` will be the machine-checkable review floor that pkgreview's skills consume (#82) | washr #82 | owdata's `has_*` diagnostics overlap. Name them after the gates so the two map one to one. |
| `setup_datadict()` writes `data-dict.yaml` from the dictionary and the data (#105, v1.2.0), with the YAML as a possible canonical source later (#108, backlog) | washr #105, #108 | A second, richer variable source (units, enum values, ranges) that #3's parsers should be able to take when it exists. Not now. |
| Config/washr fields in DESCRIPTION for funder, analytics, DOI provider and Pages domain, and a sweep so every function reads the org from DESCRIPTION (#81, v1.2.0) | washr #81 | owdata's harvest hardcodes `openwashdata`. Make the org an argument of `harvest_github()` from the first commit. |
| Rename deferred (#112 stays in the backlog) | washr #112 | No effect on the `owd_` prefix. |

## 2. Recommended updates to the owdata issues

Ordered by how much they change.

1. **#11, website switchover.** Rewrite: the sheet lost its writer in washr 1.1.0, so the switchover is a launch criterion with an owner and a date, as the premortem already asked. Replace "soft-deprecate `update_gsheet_metadata()`" with "owdata closes washr #69". The catalog must carry `location`, `temporal_coverage`, `keywords`, `maintainer` and `doi` before the website can read it, because the sheet already has them. The washr documentation item moves to three places: the guide (#85 rework), the vignette, and the washr skill's SKILL.md (#115).

2. **#5, data model.** Add to `owd_packages`: `keywords` (from `X-schema.org-keywords`, GitHub topics as fallback, keep `topics` as its own column), `spatial_coverage`, `temporal_coverage`, `has_ci`, `has_jsonld` (a `pkgdown/templates/in-header.html` with a `ld+json` block exists), `washr_version` when the Config field of #81 lands. Replace `csv_url` and `xlsx_url` in `owd_datasets` by a fourth table, `owd_files` (pkg_name, dataset_name, file_name, format, mime_type, url), built with washr's matching rule: a file belongs to a dataset when its name starts with the dataset name and a dot. This survives parquet (#106) and `.csv.gz` without a schema change every time a format is added, and `csv_url` can stay as a convenience column derived from it. Use `default_branch` in the URL.

3. **#3, parsers.** Add the `c("POSIXct", "POSIXt")` variable_type pathology and normalise it to the first class. Parse DESCRIPTION with `desc::desc(text = )` and `CITATION.cff` with `cffr::cff_read()` from the fetched text rather than with regexes, so owdata reads the files the same way washr writes them. Define the parser interface so a `parse_datadict()` can be added when #105 exists, and reserve `units` and `values` columns in `owd_variables` as all-NA until then.

4. **#1, scaffold.** Scaffold owdata with washr itself: `usethis::create_package()`, then `washr::setup_ci()`, `washr::update_description()`, `washr::setup_website()` (writes the org `_pkgdown.yml` with the Plausible header, the funding sidebar and the reference index; leaves `docs/` ignored once the pkgdown workflow exists), `washr::use_brand()`, `washr::setup_dictionary()` and `washr::setup_roxygen()` for the three tibbles, `washr::update_citation()` before the first release. Copy `test-coverage.yaml` from washr. This replaces the "copy washmalawi's pattern" instruction in #7 and makes owdata pass its own tier policy by construction. Keep CC BY 4.0 as planned; it is on CRAN's license list and the catalog content is derived from CC BY 4.0 packages.

5. **#2, tier policy.** No change to the tiers. Add the premortem's day-one check of the four closed pkgreview issues, and note that when washr #82 ships, the harvest should not reimplement its gates; it records what GitHub shows cheaply and leaves file-level readiness to washr.

6. **#4, harvester.** `harvest_github(org = "openwashdata")` from the start, mirroring washr's generalisation. Keep washr and owdata hardcoded in the r-universe `packages.json` generation with a test, as the premortem asked.

7. **#6, exports.** Unchanged. Imports stay `tibble` plus base; `desc`, `cffr`, `gh`, `yaml`, `jsonlite`, `writexl` live in Suggests because only `data-raw/` and the tests use them. Consider `cli` for the attach message only if #84 makes it the org convention; `packageStartupMessage()` is enough today.

8. **#9, weekly harvest.** Bump the fourth version component and set `Date` on every harvest commit, so r-universe rebuilds and `update.packages()` sees a change (the premortem's staleness finding on #5). washr's `update_description()` already writes `Date`.

9. **#12, tracking.** Add one convention: owdata is engine only, no skill; the harvest is a script, not a prompt. Add a row for washr #69 under Phase 5 so the sheet's retirement is tracked here.

Nothing in the plan is invalidated. The premortem's ordering stands: phases 1 and 2 are coding work that fits one maintainer; phases 3 to 5 are the coordination-heavy part, and washr 1.2.0 (the skill, the readiness gate, data-dict, parquet, the config sweep) now competes for the same person in the same window.

## 3. Best practices for R package development with Claude

Sources reachable from this environment: the posit-dev/skills repository and the raw SKILL.md files, the community skill repositories on GitHub, and the awesome-rstats-skills catalogue. Blocked by the egress proxy: opensource.posit.co, rworks.dev, r-bloggers.com, infoworld.com; their content is known only through search snippets.

### 3.1 Posit's skills are the baseline

Posit publishes skills at github.com/posit-dev/skills. Install in Claude Code with:

```
/plugin marketplace add posit-dev/skills
/plugin install r-lib@posit-dev-skills
```

The r-lib category holds `r-package-development` (Simon Couch), `testing-r-packages`, `cli`, `cran-extrachecks`, `lifecycle`, `mirai` and `alt-text`. The `open-source` category adds `create-release-checklist` and `release-post`; `github` adds `pr-create`, `pr-threads-address`, `pr-threads-resolve`.

What `r-package-development` prescribes, verified against the raw file:

- Run everything through `Rscript -e "devtools::test()"`, `devtools::document()`, `devtools::check()`, and format with `air format .`.
- Base pipe `|>`, never `%>%`; `\()` for one-line anonymous functions.
- Tests for `R/name.R` live in `tests/testthat/test-name.R`; every new function gets a test; avoid `expect_true()` and `expect_false()`; use `expect_snapshot(error = TRUE)` for errors.
- Roxygen wrapped at 80 characters; internal functions get no roxygen; add new topics to `_pkgdown.yml` and run `pkgdown::check_pkgdown()`.
- NEWS.md: one bullet per user-facing change, function name early, issue number in parentheses, bullets alphabetical by function.

The file contains no guidance on base R versus tidyverse and no rules on Imports. Third-party marketplace listings that advertise "Base R vs Tidyverse dependency management" describe community skills, not Posit's.

`testing-r-packages` adds: fixtures under `tests/testthat/fixtures/` read with `test_path()`, state managed with `withr::local_*()`, every test self-sufficient, snapshot tests for complex output. washr's test suite already follows this; owdata's #3 fixture plan matches it.

### 3.2 Community skills worth knowing

- ab604/claude-code-r-skills: `tidyverse-patterns`, `r-package-development`, `r-performance`, `r-oop`, `tdd-workflow`, rules, hooks and commands; bundles Posit's `testing-r-packages`. No base R skill.
- jeremy-allen/claude-skills: `writing-tidyverse-r` (analysis code), `developing-packages-r` (dependency rule: base R for simple utilities, add a dependency for a real functionality gain, dplyr and purrr "usually worth it" for complex manipulation), `optimizing-r` (profile first; a decision matrix of base R when no dependencies are allowed, dplyr for readability, data.table above a gigabyte).
- jsperger/llm-r-skills: `designing-tidy-r-functions`, `rlang-conditions`, `tidy-evaluation`; no base R skill.
- GiulSposito/r-claude-skills: 26 skills, tidyverse and modelling heavy; no base R skill.
- christopherkenny/awesome-rstats-skills: the catalogue; lists `base-r-skill` by iremaydas as the only base R entry.
- tidyverse/data-dict ships agent skills for authoring dictionaries, relevant to washr #105.

There is no `tidyverse/skills` repository (404) and no skill named "efficient base R" in any of these sources.

### 3.3 Practices that the search and the two repositories agree on

1. Put the deterministic work in tested functions and let the skill drive them. washr decided this in #111; the guiding rule "if a script appears inside the skill, the function belongs in washr" is the org's own formulation of what the Posit skills assume.
2. Idempotent functions and structured output matter more for an agent than for a person (#73 shipped, #84 pending). Claude re-runs functions after editing files and parses what they print.
3. A CLAUDE.md per repository with the workflow commands, the branch policy (dev, PR, main), the style rules (no em dashes, en-GB, blank line after headings), the test bar, and what is generated and never hand-edited (NAMESPACE, man/, data/, inst/extdata). Neither repository has one today.
4. A SessionStart hook or setup script that installs R and the package dependencies, so Claude on the web can run `devtools::test()` before pushing. This session's container has no R, so nothing pushed from here was checked.
5. Skills loaded for the task, not globally: package mechanics from Posit's r-lib set on every session; a tidyverse skill only when writing analysis or `data-raw/` code.

## 4. Tidyverse skills or efficient base R skills

Neither as the primary skill for package code. The Posit r-lib skills are the ones that match the work, and they already settle the idiom question for `R/`: base pipe, base anonymous functions, and no view on dplyr because a package's `R/` directory rarely needs it.

The choice is already made in both repositories. washr 1.1.0 removed dplyr, readr, stringr and tibble from Imports on purpose; owdata #6 says "base subsetting plus tibble; no dplyr in exported code". A tidyverse-patterns skill loaded while editing `R/` pulls Claude toward `mutate(.by = )`, `str_*()` and `map()`, which re-introduce the dependencies the cut removed and which every CRAN check then carries. An "efficient base R" skill fails the other way: it invites `for` loop and vectorisation dogma and premature optimisation on inputs of 70 packages and 2,500 rows, where nothing is slow.

Where the tidyverse is right: `data-raw/harvest.R`, the DT articles in `vignettes/articles/`, downstream `data_processing.R` scripts, and the README template, which already loads dplyr, readr, stringr and gt. None of those are Imports.

Recommendation, in one rule for CLAUDE.md in both repositories:

> Code under `R/` uses base R and the packages already in Imports. Do not add tidyverse packages to Imports. dplyr, purrr, stringr and readr are fine in `data-raw/`, `vignettes/` and tests.

With that rule in place: install Posit's r-lib skills for every session, add a tidyverse skill (ab604's `tidyverse-patterns` or jeremy-allen's `writing-tidyverse-r`) for analysis and `data-raw/` work, and skip a base R skill. Posit's `cli` skill is the one to add when washr #84 starts.
