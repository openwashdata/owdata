#' List the openwashdata packages in the catalog
#'
#' Returns the harvested package table. All tiers are listed, including
#' packages still in development; use the tier argument to restrict the
#' result.
#'
#' @param tier Optional character vector of tiers to keep. One or more of
#'   "dev", "candidate", "catalogued". NULL (the default) returns all
#'   rows.
#' @return A tibble with one row per package. See the package index
#'   article for the column reference.
#' @export
#' @examples
#' owd_packages()
#' owd_packages(tier = "catalogued")
#' owd_packages(tier = c("catalogued", "candidate"))
owd_packages <- function(tier = NULL) {
  out <- owd_active_catalog()$packages
  if (!is.null(tier)) {
    tier <- match.arg(as.character(tier), owd_tier_levels(), several.ok = TRUE)
    out <- out[out$tier %in% tier, , drop = FALSE]
  }
  out
}

#' List the datasets shipped by catalogued and candidate packages
#'
#' Dataset detail is only harvested for packages in the candidate and
#' catalogued tiers; packages still in development appear in
#' [owd_packages()] but not here.
#'
#' @param pkg Optional character vector of package names to keep. NULL
#'   (the default) returns all rows.
#' @return A tibble with one row per dataset.
#' @export
#' @examples
#' owd_datasets()
#' owd_datasets(pkg = "washmalawi")
owd_datasets <- function(pkg = NULL) {
  out <- owd_active_catalog()$datasets
  if (!is.null(pkg)) {
    owd_check_pkg_names(pkg)
    out <- out[out$pkg_name %in% pkg, , drop = FALSE]
  }
  out
}

#' List the documented variables across the catalog
#'
#' The cross-package variable dictionary, harvested from each package's
#' data-raw/dictionary.csv. Same tier scope as [owd_datasets()].
#'
#' @param pkg Optional character vector of package names to keep.
#' @param dataset Optional character vector of dataset names to keep.
#' @return A tibble with one row per documented variable.
#' @export
#' @examples
#' owd_variables(pkg = "washmalawi")
#' head(owd_variables())
owd_variables <- function(pkg = NULL, dataset = NULL) {
  out <- owd_active_catalog()$variables
  if (!is.null(pkg)) {
    owd_check_pkg_names(pkg)
    out <- out[out$pkg_name %in% pkg, , drop = FALSE]
  }
  if (!is.null(dataset)) {
    out <- out[out$dataset_name %in% dataset, , drop = FALSE]
  }
  out
}

# Stop with a helpful message when a requested package is not in the
# catalog at all.
owd_check_pkg_names <- function(pkg) {
  known <- owd_active_catalog()$packages$pkg_name
  unknown <- setdiff(pkg, known)
  if (length(unknown) > 0) {
    stop(
      "Not in the openwashdata catalog: ",
      paste(unknown, collapse = ", "),
      ". See owd_packages() for the full list.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
