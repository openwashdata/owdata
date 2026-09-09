# List the openwashdata packages in the catalog

Returns the harvested package table. Every detected package is listed,
whether or not it has been published; use `published` to restrict the
result.

## Usage

``` r
owd_packages(published = NULL)
```

## Arguments

- published:

  Optional logical. `TRUE` keeps published packages, `FALSE` keeps the
  rest, `NULL` (the default) returns all rows.

## Value

A tibble with one row per package and these columns: `pkg_name`,
`title`, `description`, `version` (leading v stripped), `published`,
`reviewed` (NA until the pkgreview check is wired), `maintainer`,
`maintainer_orcid`, `authors`, `license`, `date`, `keywords`,
`spatial_coverage`, `temporal_coverage`, `doi`, `cff_version`,
`url_github`, `url_docs`, `n_datasets`, `latest_release`,
`default_branch`, `created_at`, `last_commit`, `topics`,
`has_dictionary`, `has_extdata`, and the tooling provenance columns
`washr_version`, `brand_ref`, `pkgreview_standard`, `has_r_cmd_check`,
`has_pkgdown_workflow` and `has_jsonld`.

## Details

A package counts as published when its `CITATION.cff` carries a Zenodo
DOI. There are no version tiers, so a version number says nothing about
whether a package is published.

## Examples

``` r
owd_packages()
#> # A tibble: 64 × 32
#>    pkg_name              title description version published reviewed maintainer
#>    <chr>                 <chr> <chr>       <chr>   <lgl>     <lgl>    <chr>     
#>  1 artesianwells         Arte… A dataset … 0.1.0   TRUE      NA       Emmanuel …
#>  2 basisghana            Basi… This packa… 0.0.0.… FALSE     NA       Lars Schö…
#>  3 biogasoutcomesmalawi  Data… This datas… 0.0.1   TRUE      NA       Lars Schö…
#>  4 boreholeforensicspum… Bore… This datas… 0.1.0   TRUE      NA       Emmanuel …
#>  5 boreholefuncmwi       Anal… The data i… 0.0.1   TRUE      NA       Mabvuto Y…
#>  6 boreholelabdata       Wate… This datas… 0.0.0.… FALSE     NA       Emmanuel …
#>  7 breathablepitlat      Data… This datas… 0.0.0.… TRUE      NA       Mian Zhong
#>  8 cbssuitabilityhaiti   Data… This packa… 0.0.1   TRUE      NA       Sebastian…
#>  9 chckapmalawi          Know… This datas… 0.0.0.… FALSE     NA       Sophia Sk…
#> 10 choleramalawi         Trac… A dataset … 0.1.0   TRUE      NA       Yash Dubey
#> # ℹ 54 more rows
#> # ℹ 25 more variables: maintainer_orcid <chr>, authors <chr>, license <chr>,
#> #   date <date>, keywords <chr>, spatial_coverage <chr>,
#> #   temporal_coverage <chr>, doi <chr>, cff_version <chr>, url_github <chr>,
#> #   url_docs <chr>, n_datasets <int>, latest_release <chr>,
#> #   default_branch <chr>, created_at <date>, last_commit <date>, topics <chr>,
#> #   has_dictionary <lgl>, has_extdata <lgl>, washr_version <chr>, …
owd_packages(published = TRUE)
#> # A tibble: 32 × 32
#>    pkg_name              title description version published reviewed maintainer
#>    <chr>                 <chr> <chr>       <chr>   <lgl>     <lgl>    <chr>     
#>  1 artesianwells         Arte… A dataset … 0.1.0   TRUE      NA       Emmanuel …
#>  2 biogasoutcomesmalawi  Data… This datas… 0.0.1   TRUE      NA       Lars Schö…
#>  3 boreholeforensicspum… Bore… This datas… 0.1.0   TRUE      NA       Emmanuel …
#>  4 boreholefuncmwi       Anal… The data i… 0.0.1   TRUE      NA       Mabvuto Y…
#>  5 breathablepitlat      Data… This datas… 0.0.0.… TRUE      NA       Mian Zhong
#>  6 cbssuitabilityhaiti   Data… This packa… 0.0.1   TRUE      NA       Sebastian…
#>  7 choleramalawi         Trac… A dataset … 0.1.0   TRUE      NA       Yash Dubey
#>  8 ds4owdanalytics       DS4O… Data colle… 0.1.0   TRUE      NA       Yash Dubey
#>  9 fecalcanuga           Demo… This data … 0.1.0   TRUE      NA       Kelsey Sh…
#> 10 floodchlorinationsur… USAI… This R pac… 0.1.0   TRUE      NA       Emmanuel …
#> # ℹ 22 more rows
#> # ℹ 25 more variables: maintainer_orcid <chr>, authors <chr>, license <chr>,
#> #   date <date>, keywords <chr>, spatial_coverage <chr>,
#> #   temporal_coverage <chr>, doi <chr>, cff_version <chr>, url_github <chr>,
#> #   url_docs <chr>, n_datasets <int>, latest_release <chr>,
#> #   default_branch <chr>, created_at <date>, last_commit <date>, topics <chr>,
#> #   has_dictionary <lgl>, has_extdata <lgl>, washr_version <chr>, …
```
