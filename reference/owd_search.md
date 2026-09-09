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
#> # A tibble: 64 × 5
#>    pkg_name            match_type dataset_name field       text                 
#>    <chr>               <chr>      <chr>        <chr>       <chr>                
#>  1 basisghana          package    NA           title       Basic Sanitation Inf…
#>  2 cbssuitabilityhaiti package    NA           title       Data for a sanitatio…
#>  3 dowaodfsurvey       package    NA           title       ODF Sanitation and H…
#>  4 fecalcanuga         package    NA           title       Demographic, Environ…
#>  5 glaas               package    NA           title       Complete Data from t…
#>  6 saniabidjan         package    NA           title       Data About Behavior …
#>  7 thyolocbcc          package    NA           title       WASH and Sanitation …
#>  8 washinvestments     package    NA           title       Multilateral develop…
#>  9 washopenresearch    package    NA           title       Dataset about open r…
#> 10 basisghana          package    NA           description This package compile…
#> # ℹ 54 more rows
owd_search("water", fields = "variable_name")
#> # A tibble: 76 × 5
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
#> 10 fecalcanuga                  variable   household_survey          vari… water
#> # ℹ 66 more rows
```
