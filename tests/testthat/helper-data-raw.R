# The tier policy and the harvest parsers live in data-raw/, which is
# not part of the built package, so their tests only run from a source
# checkout (devtools::test(), CI on the repo) and are skipped inside
# R CMD check of the built tarball.

data_raw_path <- function(file) {
  testthat::test_path("..", "..", "data-raw", file)
}

has_data_raw <- function() {
  file.exists(data_raw_path("tier_policy.R"))
}

data_raw_env <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      e <- new.env(parent = globalenv())
      for (f in c("tier_policy.R", "harvest_helpers.R")) {
        sys.source(data_raw_path(f), envir = e)
      }
      cache <<- e
    }
    cache
  }
})

fixture_path <- function(file) {
  testthat::test_path("fixtures", file)
}
