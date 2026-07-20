#' owdata: Index of openwashdata R Data Packages
#'
#' owdata ships a harvested catalog of the openwashdata R data packages,
#' their datasets and their variables. The catalog is compiled into the
#' package as an internal snapshot and regenerated weekly by an automated
#' harvest of the openwashdata GitHub organization; [owd_refresh()]
#' fetches the latest published snapshot without reinstalling.
#'
#' The catalog is exposed through accessor functions rather than lazy
#' data objects, so the same names serve both the installed snapshot and
#' a refreshed one:
#'
#' - [owd_packages()]: one row per package, all tiers
#' - [owd_datasets()]: one row per dataset, candidate and catalogued tiers
#' - [owd_variables()]: one row per documented variable
#' - [owd_search()]: regex search across all of the above
#' - [owd_install()]: install packages from the openwashdata R-universe
#'
#' Machine-readable copies of the catalog ship in `inst/extdata/` as CSV,
#' XLSX and a single catalog.json bundle.
#'
#' @keywords internal
"_PACKAGE"
