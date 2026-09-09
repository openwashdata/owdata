# List the documented variables across the catalog

The cross-package variable dictionary, harvested from each package's
`data-raw/dictionary.csv`. Published packages only, as in
[`owd_datasets()`](https://openwashdata.github.io/owdata/reference/owd_datasets.md).

## Usage

``` r
owd_variables(pkg = NULL, dataset = NULL)
```

## Arguments

- pkg:

  Optional character vector of package names to keep.

- dataset:

  Optional character vector of dataset names to keep.

## Value

A tibble with one row per documented variable, with columns `pkg_name`,
`dataset_name`, `variable_name`, `variable_type` (first class only) and
`description`.

## Examples

``` r
owd_variables(pkg = "washmalawi")
#> # A tibble: 26 × 5
#>    pkg_name   dataset_name variable_name               variable_type description
#>    <chr>      <chr>        <chr>                       <chr>         <chr>      
#>  1 washmalawi washmalawi   date_submitted              character     The date o…
#>  2 washmalawi washmalawi   latitude                    numeric       The geogra…
#>  3 washmalawi washmalawi   longitude                   numeric       The geogra…
#>  4 washmalawi washmalawi   water_point_identification… character     Method use…
#>  5 washmalawi washmalawi   traditional_authority       character     The name o…
#>  6 washmalawi washmalawi   district                    character     The name o…
#>  7 washmalawi washmalawi   water_source_type           character     Type of wa…
#>  8 washmalawi washmalawi   water_source_location       character     Location o…
#>  9 washmalawi washmalawi   water_collection_time_mins  numeric       Estimated …
#> 10 washmalawi washmalawi   time_not_known              logical       TRUE if re…
#> # ℹ 16 more rows
head(owd_variables())
#> # A tibble: 6 × 5
#>   pkg_name      dataset_name  variable_name         variable_type description   
#>   <chr>         <chr>         <chr>                 <chr>         <chr>         
#> 1 artesianwells artesianwells date_submitted        character     Date when the…
#> 2 artesianwells artesianwells latitude              numeric       Latitude coor…
#> 3 artesianwells artesianwells longitude             numeric       Longitude coo…
#> 4 artesianwells artesianwells artesian_well         character     Indicates whe…
#> 5 artesianwells artesianwells district              character     Administrativ…
#> 6 artesianwells artesianwells traditional_authority character     Traditional a…
```
