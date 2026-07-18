#' Install openwashdata packages from r-universe
#'
#' Installs one or more openwashdata data packages from the
#' openwashdata r-universe, falling back to CRAN for dependencies.
#'
#' @param pkg Character vector of package names. `NULL` installs all
#'   catalogued packages after an interactive confirmation showing the
#'   count; in non-interactive sessions `pkg` must be given explicitly.
#' @param ... Passed on to [utils::install.packages()].
#'
#' @return Invisibly, the character vector of package names requested.
#' @export
#'
#' @examples
#' \dontrun{
#' owd_install("washmalawi")
#' owd_install() # all catalogued packages, asks first
#' }
owd_install <- function(pkg = NULL, ...) {
  repos <- c(
    "https://openwashdata.r-universe.dev",
    "https://cloud.r-project.org"
  )
  if (is.null(pkg)) {
    catalogued <- owd_packages(tier = "catalogued")$pkg_name
    if (length(catalogued) == 0) {
      stop(
        "The installed catalog lists no catalogued packages. ",
        "Run owd_refresh() or name packages explicitly."
      )
    }
    if (!interactive()) {
      stop(
        "pkg = NULL installs all ", length(catalogued),
        " catalogued packages; in non-interactive sessions name them explicitly."
      )
    }
    answer <- utils::askYesNo(
      sprintf("Install all %d catalogued packages?", length(catalogued)),
      default = FALSE
    )
    if (!isTRUE(answer)) {
      return(invisible(character()))
    }
    pkg <- catalogued
  }
  utils::install.packages(pkg, repos = repos, ...)
  invisible(pkg)
}
