# owdata

## Purpose

owdata is the index metapackage for the openwashdata R data packages. It ships a harvested catalog of the packages, their datasets and their variables as internal data behind accessor functions, and it is an engine only, so the harvest is a script and there is no owdata skill.

## Layout

- `R/` holds the accessors, `owd_search()`, `owd_install()`, `parsers.R` and `zzz.R` for the startup message.
- `R/sysdata.rda` is the internal catalog snapshot.
- `inst/extdata/` holds `owd_packages.csv`, `owd_datasets.csv` and `owd_variables.csv`.
- `data-raw/` holds `harvest.R`, `harvest_helpers.R` with the local and GitHub backends, `exclude_repos.csv`, `packages.json` and `harvest_report.md`.
- `tests/testthat/` holds `test-parsers.R`, `test-schema.R` and `fixtures/`.
- `.github/workflows/` holds R-CMD-check, pkgdown, test-coverage and harvest.
- `_pkgdown.yml` and `_brand.yml` are written by washr. `dev/` holds the decisions.

Generated files, never edited by hand: `R/sysdata.rda`, `inst/extdata/`, `man/`, `NAMESPACE`, `data-raw/packages.json`, `data-raw/harvest_report.md`. The parsers, harvest, data model and exports land with issues #3 to #6.

## Commands

```
Rscript -e "devtools::document()"
Rscript -e "devtools::test()"
Rscript -e "devtools::check()"
Rscript data-raw/harvest.R
```

Run the harvest with the local backend in a UTF-8 locale. The GitHub backend is never run from tests.

## Branches

One maintainer. Work happens on a branch with a pull request to main. There is no dev branch. The harvest bot opens a pull request and never pushes to main. Never commit generated data by hand.

## Dependencies

Code under `R/` uses base R and the packages already in Imports (tibble, utils). Do not add tidyverse packages to Imports. dplyr, purrr, stringr and readr are fine in `data-raw/` and tests.

## Tests

One behavioural test per export. Every `expect_error()` names its message. Fixtures live under `tests/testthat/fixtures/` and are read with `test_path()`. The schema and value gates in `test-schema.R` gate the harvest.

## Style

No em dashes, no emojis, a blank line after every heading, en-GB.

## Pointers

Tracking issue #12. Decisions of record in `dev/decisions-2026-09.md`.
