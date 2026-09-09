#' List the openwashdata packages in the catalog
#'
#' Returns the harvested package table. Every detected package is listed,
#' whether or not it has been published; use `published` to restrict the
#' result.
#'
#' A package counts as published when its `CITATION.cff` carries a Zenodo
#' DOI. There are no version tiers, so a version number says nothing
#' about whether a package is published.
#'
#' @param published Optional logical. `TRUE` keeps published packages,
#'   `FALSE` keeps the rest, `NULL` (the default) returns all rows.
#'
#' @returns A tibble with one row per package and these columns:
#'   `pkg_name`, `title`, `description`, `version` (leading v stripped),
#'   `published`, `reviewed` (NA until the pkgreview check is wired),
#'   `maintainer`, `maintainer_orcid`, `authors`, `license`, `date`,
#'   `keywords`, `spatial_coverage`, `temporal_coverage`, `doi`,
#'   `cff_version`, `url_github`, `url_docs`, `n_datasets`,
#'   `latest_release`, `default_branch`, `created_at`, `last_commit`,
#'   `topics`, `has_dictionary`, `has_extdata`, and the tooling
#'   provenance columns `washr_version`, `brand_ref`,
#'   `pkgreview_standard`, `has_r_cmd_check`, `has_pkgdown_workflow`
#'   and `has_jsonld`.
#'
#' @export
#' @examples
#' owd_packages()
#' owd_packages(published = TRUE)
owd_packages <- function(published = NULL) {
  out <- owd_active_catalog()$packages
  if (!is.null(published)) {
    if (!is.logical(published) || length(published) != 1 || is.na(published)) {
      stop("`published` must be TRUE, FALSE or NULL.", call. = FALSE)
    }
    out <- out[out$published == published, , drop = FALSE]
  }
  out
}

#' List the datasets shipped by published packages
#'
#' Dataset detail is harvested for published packages only; an
#' unpublished package appears in [owd_packages()] but not here.
#'
#' @param pkg Optional character vector of package names to keep. NULL
#'   (the default) returns all rows.
#' @returns A tibble with one row per dataset, with columns `pkg_name`,
#'   `dataset_name`, `title`, `description`, `n_rows`, `n_vars`,
#'   `n_vars_dictionary`, `csv_url` and `xlsx_url`.
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
#' `data-raw/dictionary.csv`. Published packages only, as in
#' [owd_datasets()].
#'
#' @param pkg Optional character vector of package names to keep.
#' @param dataset Optional character vector of dataset names to keep.
#' @returns A tibble with one row per documented variable, with columns
#'   `pkg_name`, `dataset_name`, `variable_name`, `variable_type` (first
#'   class only) and `description`.
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
