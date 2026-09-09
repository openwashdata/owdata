# owdata

owdata is the index of the openwashdata R data packages. It ships a catalog of every package in the openwashdata GitHub organisation, with the datasets and the variables each package holds. A weekly harvest of the organisation refreshes the catalog, and each refresh ships as a new version of owdata.

## Installation

Install owdata from the openwashdata R-universe.

```r
install.packages("owdata", repos = c("https://openwashdata.r-universe.dev", "https://cloud.r-project.org"))
```

## Usage

Three functions return the catalog as tibbles.

- `owd_packages()` lists one row per package.
- `owd_datasets()` lists one row per dataset, with the package it belongs to.
- `owd_variables()` lists one row per variable, with the dataset it belongs to.

`owd_search("water")` finds the packages, datasets and variables whose name or description match a pattern. `owd_install("washmalawi")` installs a listed package from the openwashdata R-universe, with CRAN as the fallback.

## How a package gets listed

Publish the package with washr, mint the Zenodo DOI, and the next weekly harvest lists the package in the catalog. The harvest lists every package it finds in the organisation and records the datasets and variables of the packages that carry a DOI.

## Status

The package is a skeleton. The parsers, the harvest, the data model and the functions above land with issues #3 to #6. The plan is tracked in issue #12, and the design decisions are recorded in `dev/decisions-2026-09.md`.
