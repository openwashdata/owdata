# The catalog changes weekly while installed package data is frozen at
# install time. owd_refresh() closes that gap by fetching the current
# catalog.json from the repository and caching it; the accessors prefer
# the refreshed copy whenever it is newer than the installed data.

catalog_json_url <- function() {
  "https://raw.githubusercontent.com/openwashdata/owdata/main/inst/extdata/catalog.json"
}

refresh_cache_path <- function() {
  file.path(tools::R_user_dir("owdata", "cache"), "catalog.rds")
}

#' Refresh the catalog without reinstalling the package
#'
#' Downloads the current published catalog and caches it locally. After
#' a successful refresh, [owd_packages()], [owd_datasets()],
#' [owd_variables()], and [owd_search()] use the refreshed catalog
#' whenever it is newer than the data shipped in the installed package.
#'
#' @param quiet Suppress the confirmation message.
#'
#' @return Invisibly, `TRUE` on success and `FALSE` when the catalog
#'   could not be fetched.
#' @export
#'
#' @examples
#' \dontrun{
#' owd_refresh()
#' }
owd_refresh <- function(quiet = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("owd_refresh() needs the jsonlite package.")
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(catalog_json_url()),
    error = function(e) NULL
  )
  if (is.null(parsed) || is.null(parsed$owd_packages)) {
    if (!quiet) {
      message("Could not fetch the published catalog; keeping installed data.")
    }
    return(invisible(FALSE))
  }
  harvested <- as.Date(parsed$harvested)
  tables <- list()
  for (nm in names(owd_schema)) {
    tbl <- tibble::as_tibble(parsed[[nm]])
    proto <- empty_catalog_tbl(nm)
    missing <- setdiff(names(proto), names(tbl))
    for (col in missing) {
      tbl[[col]] <- proto[[col]][rep(NA_integer_, nrow(tbl))]
    }
    tbl <- tbl[, names(proto), drop = FALSE]
    if ("tier" %in% names(tbl)) {
      tbl$tier <- factor(tbl$tier, levels = levels(proto$tier))
    }
    for (col in c("date", "created_at", "last_commit")) {
      if (col %in% names(tbl)) {
        tbl[[col]] <- as.Date(tbl[[col]])
      }
    }
    attr(tbl, "harvested") <- harvested
    tables[[nm]] <- tbl
  }
  path <- refresh_cache_path()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(list(harvested = harvested, tables = tables), path)
  if (!quiet) {
    message(sprintf(
      "Catalog refreshed (harvested %s): %d packages.",
      format(harvested), nrow(tables$owd_packages)
    ))
  }
  invisible(TRUE)
}

# Internal: the cached refreshed table, or NULL when there is no cache
# or the installed data is at least as recent.
refreshed_table <- function(name) {
  path <- refresh_cache_path()
  if (!file.exists(path)) {
    return(NULL)
  }
  cache <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(cache) || is.null(cache$tables[[name]])) {
    return(NULL)
  }
  installed <- installed_harvest_date()
  if (!is.na(installed) && !is.na(cache$harvested) &&
        installed >= cache$harvested) {
    return(NULL)
  }
  cache$tables[[name]]
}

# The harvest date of the data shipped in the installed package,
# bypassing the refresh cache.
installed_harvest_date <- function() {
  env <- new.env(parent = emptyenv())
  got <- tryCatch(
    {
      utils::data(list = "owd_packages", package = "owdata", envir = env)
      get("owd_packages", envir = env)
    },
    warning = function(w) NULL,
    error = function(e) NULL
  )
  if (is.null(got)) {
    return(as.Date(NA))
  }
  harvested <- attr(got, "harvested")
  if (is.null(harvested)) as.Date(NA) else as.Date(harvested)
}
