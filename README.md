# owdata

Index and documentation metapackage for the openwashdata R data packages.

The openwashdata organization publishes around 70 uniform R data packages. owdata ships a harvested catalog of all of them, their datasets, and their roughly 2,700 documented variables as queryable package data, so a single package answers "which openwashdata package has data about X".

## Installation

Once the openwashdata R-universe is live:

``` r
install.packages("owdata", repos = c("https://openwashdata.r-universe.dev", "https://cloud.r-project.org"))
```

Until then, install from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("openwashdata/owdata")
```

## Usage

Search every package, dataset and variable in the organization:

``` r
library(owdata)

owd_search("groundwater")
owd_search("latrine", fields = "variable_name")
```

Browse the catalog tables:

``` r
owd_packages()
owd_packages(tier = "catalogued")
owd_datasets(pkg = "washmalawi")
owd_variables(pkg = "washmalawi")
```

Install data packages from the openwashdata R-universe:

``` r
owd_install("washmalawi")
owd_install()   # all catalogued packages, after confirmation
```

The installed catalog is a snapshot from build time. Fetch the latest published harvest at any time without reinstalling:

``` r
owd_refresh()
```

Attaching owdata never attaches or installs the indexed data packages; it prints a one-line catalog summary instead.

## The catalog

Three tables, refreshed weekly by an automated harvest of the openwashdata GitHub organization:

- `owd_packages()`: one row per package with title, version, tier, maintainer, DOI, links and quality diagnostics
- `owd_datasets()`: one row per dataset with dimensions and direct CSV and XLSX download links
- `owd_variables()`: one row per documented variable across the whole organization

Machine-readable copies ship in `inst/extdata/` as CSV, XLSX and a single `catalog.json` bundle, also published at <https://raw.githubusercontent.com/openwashdata/owdata/main/inst/extdata/catalog.json>.

Catalog inclusion is governed by a version-tier policy tied to the openwashdata review process: dev (below 0.1.0, listed only), candidate (0.1.0 and above, review requested), catalogued (1.0.0 and above with a Zenodo DOI). See the versioning policy article on the package website for the full rules, including the transitional handling of packages published before the 2026 review standard.

## How the harvest works

`data-raw/harvest.R` builds the catalog through two interchangeable backends: a GitHub backend used by the weekly workflow and a local backend that runs the identical parsing against local clones for development and tests. Hardened parsers cover every metadata pathology observed across the organization, and per-repository failures are collected as data instead of aborting the run. A schema and content test suite gates every automated commit. See `data-raw/README.md` for details.

## License

CC BY 4.0. See LICENSE.md.
