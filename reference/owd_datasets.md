# List the datasets shipped by published packages

Dataset detail is harvested for published packages only; an unpublished
package appears in
[`owd_packages()`](https://openwashdata.github.io/owdata/reference/owd_packages.md)
but not here.

## Usage

``` r
owd_datasets(pkg = NULL)
```

## Arguments

- pkg:

  Optional character vector of package names to keep. NULL (the default)
  returns all rows.

## Value

A tibble with one row per dataset, with columns `pkg_name`,
`dataset_name`, `title`, `description`, `n_rows`, `n_vars`,
`n_vars_dictionary`, `csv_url` and `xlsx_url`.

## Examples

``` r
owd_datasets()
#> # A tibble: 53 × 9
#>    pkg_name       dataset_name title description n_rows n_vars n_vars_dictionary
#>    <chr>          <chr>        <chr> <chr>        <int>  <int>             <int>
#>  1 artesianwells  artesianwel… arte… A dataset …     44     29                29
#>  2 biogasoutcome… biogasoutco… Qual… This datas…    259      5                 5
#>  3 boreholeforen… boreholefor… bore… This datas…    445     38                44
#>  4 boreholefuncm… boreholefun… bore… The data i…    108     17                17
#>  5 breathablepit… breathablep… NA    NA               6      8                 8
#>  6 cbssuitabilit… mwater       Loca… This data …   1849      7                 7
#>  7 cbssuitabilit… okap         Sani… This data …    198     21                13
#>  8 choleramalawi  choleramala… Titl… Descriptio…   1886      8                 8
#>  9 ds4owdanalyti… course_part… cour… Sessions a…    734      5                 5
#> 10 ds4owdanalyti… ds4owd_brow… ds4o… This datas…     17      6                 6
#> # ℹ 43 more rows
#> # ℹ 2 more variables: csv_url <chr>, xlsx_url <chr>
owd_datasets(pkg = "washmalawi")
#> # A tibble: 1 × 9
#>   pkg_name   dataset_name title      description n_rows n_vars n_vars_dictionary
#>   <chr>      <chr>        <chr>      <chr>        <int>  <int>             <int>
#> 1 washmalawi washmalawi   SDG House… This datas…  23112     27                26
#> # ℹ 2 more variables: csv_url <chr>, xlsx_url <chr>
```
