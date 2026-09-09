# Install openwashdata packages from the openwashdata R-universe

A thin wrapper around
[`utils::install.packages()`](https://rdrr.io/r/utils/install.packages.html)
that points at <https://openwashdata.r-universe.dev> (with CRAN as
fallback for dependencies).

## Usage

``` r
owd_install(pkg = NULL, ...)
```

## Arguments

- pkg:

  Character vector of package names to install. NULL (the default)
  installs every published package after an interactive confirmation
  showing the count; in non-interactive sessions NULL is an error, so
  scripts must name packages explicitly.

- ...:

  Passed on to
  [`utils::install.packages()`](https://rdrr.io/r/utils/install.packages.html).

## Value

Invisibly, the character vector of package names requested.

## Examples

``` r
if (FALSE) { # \dontrun{
owd_install("washmalawi")
owd_install()
} # }
```
