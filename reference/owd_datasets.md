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
#> # A tibble: 78 × 9
#>    pkg_name       dataset_name title description n_rows n_vars n_vars_dictionary
#>    <chr>          <chr>        <chr> <chr>        <int>  <int>             <int>
#>  1 artesianwells  artesianwel… arte… A dataset …     44     29                29
#>  2 basisghana     basisghana   Basi… The BaSIS …   1618     10                10
#>  3 basisghana     ghanapop     Ghan… This datas…    260      9                 9
#>  4 biogasoutcome… biogasoutco… Qual… This datas…   5963      5                 5
#>  5 boreholeforen… boreholefor… bore… This datas…    445     38                44
#>  6 boreholefuncm… boreholefun… bore… The data i…    108     17                17
#>  7 boreholelabda… boreholelab… Wate… This datas…     32     53                53
#>  8 breathablepit… breathablep… NA    NA            3132      8                 8
#>  9 cbssuitabilit… mwater       Loca… This data …   1849      7                 7
#> 10 cbssuitabilit… okap         Sani… This data …    198     13                13
#> # ℹ 68 more rows
#> # ℹ 2 more variables: csv_url <chr>, xlsx_url <chr>
owd_datasets(pkg = "washmalawi")
#> # A tibble: 1 × 9
#>   pkg_name   dataset_name title      description n_rows n_vars n_vars_dictionary
#>   <chr>      <chr>        <chr>      <chr>        <int>  <int>             <int>
#> 1 washmalawi washmalawi   SDG House… This datas…  23112     27                26
#> # ℹ 2 more variables: csv_url <chr>, xlsx_url <chr>
```
