# Search the openwashdata catalog

Runs a case-insensitive regular expression over package, dataset and
variable metadata, so `owd_search("groundwater")` answers "which package
has data about groundwater". The search runs against a prebuilt flat
index, so it is a single vectorized match regardless of catalog size.

## Usage

``` r
owd_search(
  query,
  fields = c("title", "description", "variable_name", "dataset_name")
)
```

## Arguments

- query:

  A single regular expression (case-insensitive). Plain words work
  as-is.

- fields:

  Character vector of fields to search. Any of "title", "description",
  "variable_name", "dataset_name", "pkg_name". The default covers
  titles, descriptions, variable names and dataset names.

## Value

A tibble of hits with columns pkg_name, match_type ("package", "dataset"
or "variable"), dataset_name, field and text (the matched text). Zero
rows when nothing matches.

## Examples

``` r
owd_search("sanitation")
#> # A tibble: 114 × 5
#>    pkg_name            match_type dataset_name field       text                 
#>    <chr>               <chr>      <chr>        <chr>       <chr>                
#>  1 basisghana          package    NA           title       Basic Sanitation Inf…
#>  2 cbssuitabilityhaiti package    NA           title       Sanitation Zoning an…
#>  3 fecalcanuga         package    NA           title       Non-Sewered Sanitati…
#>  4 glaas               package    NA           title       Complete Data from t…
#>  5 saniabidjan         package    NA           title       Sanitation Facility …
#>  6 washinvestments     package    NA           title       Multilateral Develop…
#>  7 washopenresearch    package    NA           title       Dataset about open r…
#>  8 basisghana          package    NA           description This package compile…
#>  9 cbssuitabilityhaiti package    NA           description This package contain…
#> 10 chckapmalawi        package    NA           description This dataset capture…
#> # ℹ 104 more rows
owd_search("water", fields = "variable_name")
#> # A tibble: 174 × 5
#>    pkg_name                     match_type dataset_name              field text 
#>    <chr>                        <chr>      <chr>                     <chr> <chr>
#>  1 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… type…
#>  2 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… wate…
#>  3 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… dist…
#>  4 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… stat…
#>  5 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… wate…
#>  6 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… othe…
#>  7 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… was_…
#>  8 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… wate…
#>  9 boreholeforensicspumpingtest variable   boreholeforensicspumping… vari… wate…
#> 10 boreholelabdata              variable   boreholelabdata           vari… wate…
#> # ℹ 164 more rows
```
