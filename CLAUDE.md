# owdata

Index metapackage for the openwashdata R data packages. A weekly harvest
of the GitHub organisation produces three tables (packages, datasets,
variables) that ship inside the package behind accessor functions and as
CSV for openwashdata.org. Engine only: the harvest is a script, and there
is no owdata skill.

Decisions of record: `dev/decisions-2026-09.md`. Tracking issue: #12.

## Layout

- `R/`: accessors, search, install, parsers, startup message
- `R/sysdata.rda`: the catalog snapshot, generated
- `inst/extdata/*.csv`: the three tables for the website, generated
- `data-raw/harvest.R`, `harvest_helpers.R`: the harvest and its backends
- `data-raw/packages.json`, `harvest_report.md`: generated
- `tests/testthat/`: tests and `fixtures/` with real pathological files

Never hand-edit generated files: `R/sysdata.rda`, `inst/extdata/`,
`man/`, `NAMESPACE`, `data-raw/packages.json`,
`data-raw/harvest_report.md`.

## Commands

```sh
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test()'
Rscript -e 'devtools::check()'
LANG=C.UTF-8 OWD_HARVEST_BACKEND=local OWD_LOCAL_ROOT=~/clones Rscript data-raw/harvest.R
```

The GitHub backend is never run from tests. Harvests must run in a UTF-8
locale; the test gate fails on `<U+xxxx>` escapes in the tables.

## Branches

Branches and pull requests to main. No dev branch. The weekly harvest
bot opens a pull request; it never pushes to main. Do not commit
generated data by hand.

## Dependencies

Code under `R/` uses base R and the packages already in Imports (tibble,
utils). Do not add tidyverse packages to Imports. dplyr, purrr, stringr
and readr are fine in `data-raw/` and tests.

## Tests

A behavioural test per export. Every `expect_error()` names its message.
Fixtures live under `tests/testthat/fixtures/` and are read with
`test_path()`. `test-schema.R` is the gate the harvest must pass: column
names and types, non-empty tables, no encoding escapes, no DOI shared by
two packages, no duplicated package name.

## Style

No em dashes, no emojis, a blank line after every heading, en-GB
spelling. NEWS.md: one bullet per user-facing change, function name
first, issue number in parentheses.
