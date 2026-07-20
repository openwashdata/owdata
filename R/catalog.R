# Active catalog resolution and the search index.
#
# The installed snapshot ships as the internal object `owd_catalog` in
# R/sysdata.rda. owd_refresh() can place a newer snapshot in the user
# cache directory; owd_active_catalog() picks whichever is newer and
# memoizes the choice for the session, so every accessor call after the
# first is a plain environment lookup.

.owd_env <- new.env(parent = emptyenv())

owd_default_catalog_url <- function() {
  getOption(
    "owdata.catalog_url",
    "https://raw.githubusercontent.com/openwashdata/owdata/main/inst/extdata/catalog.json"
  )
}

owd_cache_dir <- function() {
  dir <- Sys.getenv("OWD_CACHE_DIR", unset = "")
  if (nzchar(dir)) {
    return(dir)
  }
  tools::R_user_dir("owdata", which = "cache")
}

owd_cache_file <- function() {
  file.path(owd_cache_dir(), "catalog.rds")
}

# The snapshot compiled into the package (R/sysdata.rda).
owd_installed_catalog <- function() {
  owd_catalog
}

owd_is_catalog <- function(x) {
  is.list(x) &&
    all(c("meta", "packages", "datasets", "variables", "index") %in% names(x)) &&
    is.list(x$meta) &&
    inherits(x$meta$harvest_date, "Date") &&
    is.data.frame(x$packages) && nrow(x$packages) > 0 &&
    is.data.frame(x$datasets) &&
    is.data.frame(x$variables) &&
    is.data.frame(x$index)
}

#' Resolve the catalog used by all accessor functions
#'
#' Prefers a refreshed snapshot from the cache when it is valid and at
#' least as new as the installed one; falls back to the installed
#' snapshot on any problem. Memoized per session.
#'
#' @return The catalog list (meta, packages, datasets, variables, index).
#' @keywords internal
#' @noRd
owd_active_catalog <- function() {
  hit <- .owd_env$catalog
  if (!is.null(hit)) {
    return(hit)
  }
  cat <- owd_installed_catalog()
  cache <- owd_cache_file()
  if (file.exists(cache)) {
    refreshed <- tryCatch(readRDS(cache), error = function(e) NULL)
    if (owd_is_catalog(refreshed) &&
        isTRUE(refreshed$meta$harvest_date >= cat$meta$harvest_date)) {
      cat <- refreshed
    }
  }
  .owd_env$catalog <- cat
  cat
}

owd_forget_catalog <- function() {
  .owd_env$catalog <- NULL
  invisible(NULL)
}

# --- search index -----------------------------------------------------------

#' Build the flat search index from the three catalog tables
#'
#' One row per searchable text field. Built once at harvest (and on
#' refresh), so owd_search() is a single vectorized grepl at query time.
#'
#' @return A tibble with columns pkg_name, match_type, dataset_name,
#'   field, text.
#' @keywords internal
#' @noRd
owd_build_index <- function(packages, datasets, variables) {
  piece <- function(pkg_name, match_type, dataset_name, field, text) {
    keep <- !is.na(text) & nzchar(text)
    tibble::tibble(
      pkg_name = pkg_name[keep],
      match_type = match_type,
      dataset_name = dataset_name[keep],
      field = field,
      text = text[keep]
    )
  }
  na <- function(n) rep(NA_character_, n)
  out <- rbind(
    piece(packages$pkg_name, "package", na(nrow(packages)), "pkg_name", packages$pkg_name),
    piece(packages$pkg_name, "package", na(nrow(packages)), "title", packages$title),
    piece(packages$pkg_name, "package", na(nrow(packages)), "description", packages$description),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "dataset_name", datasets$dataset_name),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "title", datasets$title),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "description", datasets$description),
    piece(variables$pkg_name, "variable", variables$dataset_name, "variable_name", variables$variable_name),
    piece(variables$pkg_name, "variable", variables$dataset_name, "description", variables$description)
  )
  out
}

# --- catalog.json round trip ------------------------------------------------

#' Serialize the catalog to the machine-readable catalog.json bundle
#'
#' @param cat A catalog list.
#' @param path Output file path.
#' @keywords internal
#' @noRd
owd_write_catalog_json <- function(cat, path) {
  bundle <- list(
    meta = cat$meta,
    packages = cat$packages,
    datasets = cat$datasets,
    variables = cat$variables
  )
  json <- jsonlite::toJSON(
    bundle,
    dataframe = "rows", na = "null", auto_unbox = TRUE,
    Date = "ISO8601", POSIXt = "ISO8601", factor = "string",
    pretty = FALSE, digits = NA
  )
  writeLines(json, path, useBytes = TRUE)
  invisible(path)
}

#' Read a catalog.json bundle back into a catalog list
#'
#' Restores column types that JSON cannot carry (Date columns, the tier
#' factor, integer counts) and rebuilds the search index.
#'
#' @param path Path to a catalog.json file.
#' @return A catalog list.
#' @keywords internal
#' @noRd
owd_read_catalog_json <- function(path) {
  raw <- jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
  if (!is.list(raw) ||
      !all(c("meta", "packages", "datasets", "variables") %in% names(raw)) ||
      !is.data.frame(raw$packages) || !is.data.frame(raw$datasets) ||
      !is.data.frame(raw$variables)) {
    stop("File is not a catalog.json bundle: ", path)
  }
  chr_or_na <- function(x, n) {
    if (is.null(x)) rep(NA_character_, n) else as.character(x)
  }
  pk <- tibble::as_tibble(raw$packages)
  n <- nrow(pk)
  for (col in c("date", "created_at", "last_commit")) {
    pk[[col]] <- as.Date(chr_or_na(pk[[col]], n))
  }
  pk$tier <- factor(as.character(pk$tier), levels = owd_tier_levels())
  pk$legacy <- as.logical(pk$legacy)
  pk$has_dictionary <- as.logical(pk$has_dictionary)
  pk$has_extdata <- as.logical(pk$has_extdata)
  pk$n_datasets <- as.integer(pk$n_datasets)

  ds <- tibble::as_tibble(raw$datasets)
  ds$n_rows <- as.integer(ds$n_rows)
  ds$n_vars <- as.integer(ds$n_vars)
  ds$n_vars_dictionary <- as.integer(ds$n_vars_dictionary)

  vr <- tibble::as_tibble(raw$variables)

  meta <- raw$meta
  meta$harvest_date <- as.Date(meta$harvest_date)

  list(
    meta = meta,
    packages = pk,
    datasets = ds,
    variables = vr,
    index = owd_build_index(pk, ds, vr)
  )
}
