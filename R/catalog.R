# The catalog object and the one place it is read from.
#
# The harvest writes owd_catalog into R/sysdata.rda. Every accessor reads
# it through owd_active_catalog(), so the tables can only come from one
# place (#6). There is no refresh function and no user cache: the harvest
# date in the startup message is the whole staleness signal
# (dev/decisions-2026-09.md, section 2).

.owd_env <- new.env(parent = emptyenv())

#' Is this object a well formed catalog?
#'
#' @param x Any object.
#' @return TRUE when x carries the five catalog elements.
#' @keywords internal
#' @noRd
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

#' The catalog every accessor reads
#'
#' Memoized per session. The object ships inside the package, so this
#' never touches the network or the filesystem beyond the installed
#' sysdata.
#'
#' @return The catalog list (meta, packages, datasets, variables, index).
#' @keywords internal
#' @noRd
owd_active_catalog <- function() {
  hit <- .owd_env$catalog
  if (!is.null(hit)) {
    return(hit)
  }
  if (!owd_is_catalog(owd_catalog)) {
    stop("The installed owdata catalog is malformed; reinstall the package.", call. = FALSE)
  }
  .owd_env$catalog <- owd_catalog
  owd_catalog
}

# --- search index -----------------------------------------------------------

#' Build the flat search index from the three catalog tables
#'
#' One row per searchable text field. Built once at harvest, so
#' owd_search() is a single vectorized grepl at query time.
#'
#' @param packages,datasets,variables The three catalog tables.
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
  rbind(
    piece(packages$pkg_name, "package", na(nrow(packages)), "pkg_name", packages$pkg_name),
    piece(packages$pkg_name, "package", na(nrow(packages)), "title", packages$title),
    piece(packages$pkg_name, "package", na(nrow(packages)), "description", packages$description),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "dataset_name", datasets$dataset_name),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "title", datasets$title),
    piece(datasets$pkg_name, "dataset", datasets$dataset_name, "description", datasets$description),
    piece(variables$pkg_name, "variable", variables$dataset_name, "variable_name", variables$variable_name),
    piece(variables$pkg_name, "variable", variables$dataset_name, "description", variables$description)
  )
}
