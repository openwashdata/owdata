#' Catalog of openwashdata packages
#'
#' Returns the harvested package-level catalog table. Before the first
#' harvest has shipped, the table is empty but keeps its full schema.
#'
#' @param tier Optional character vector of tiers to keep, from
#'   `"dev"`, `"candidate"`, `"catalogued"`. `NULL` returns all rows.
#'
#' @return A tibble with one row per openwashdata data package.
#' @export
#'
#' @examples
#' owd_packages()
#' owd_packages(tier = c("catalogued", "candidate"))
owd_packages <- function(tier = NULL) {
  tbl <- catalog_table("owd_packages")
  if (is.null(tier)) {
    return(tbl)
  }
  tier <- match.arg(
    tier,
    choices = levels(owd_schema$owd_packages$tier),
    several.ok = TRUE
  )
  tbl[!is.na(tbl$tier) & tbl$tier %in% tier, , drop = FALSE]
}

#' Catalog of openwashdata datasets
#'
#' Returns the harvested dataset-level catalog table. Dataset detail is
#' harvested for candidate- and catalogued-tier packages only.
#'
#' @param pkg Optional character vector of package names to keep.
#'
#' @return A tibble with one row per dataset.
#' @export
#'
#' @examples
#' owd_datasets()
owd_datasets <- function(pkg = NULL) {
  tbl <- catalog_table("owd_datasets")
  if (is.null(pkg)) {
    return(tbl)
  }
  tbl[tbl$pkg_name %in% pkg, , drop = FALSE]
}

#' Catalog of openwashdata variables
#'
#' Returns the harvested variable-level catalog table: every variable
#' documented in the data dictionaries of candidate- and
#' catalogued-tier packages.
#'
#' @param pkg Optional character vector of package names to keep.
#' @param dataset Optional character vector of dataset names to keep.
#'
#' @return A tibble with one row per documented variable.
#' @export
#'
#' @examples
#' owd_variables()
owd_variables <- function(pkg = NULL, dataset = NULL) {
  tbl <- catalog_table("owd_variables")
  if (!is.null(pkg)) {
    tbl <- tbl[tbl$pkg_name %in% pkg, , drop = FALSE]
  }
  if (!is.null(dataset)) {
    tbl <- tbl[tbl$dataset_name %in% dataset, , drop = FALSE]
  }
  tbl
}
