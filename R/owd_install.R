#' Install openwashdata packages from the openwashdata R-universe
#'
#' A thin wrapper around [utils::install.packages()] that points at
#' <https://openwashdata.r-universe.dev> (with CRAN as fallback for
#' dependencies).
#'
#' @param pkg Character vector of package names to install. NULL (the
#'   default) installs every catalogued package after an interactive
#'   confirmation showing the count; in non-interactive sessions NULL is
#'   an error, so scripts must name packages explicitly.
#' @param ... Passed on to [utils::install.packages()].
#' @return Invisibly, the character vector of package names requested.
#' @export
#' @examples
#' \dontrun{
#' owd_install("washmalawi")
#' owd_install()
#' }
owd_install <- function(pkg = NULL, ...) {
  repos <- c(
    openwashdata = "https://openwashdata.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
  if (is.null(pkg)) {
    catalogued <- owd_packages(tier = "catalogued")$pkg_name
    if (length(catalogued) == 0) {
      stop("The catalog lists no catalogued packages yet.", call. = FALSE)
    }
    if (!interactive()) {
      stop(
        "pkg = NULL would install all ", length(catalogued),
        " catalogued packages. Name packages explicitly in scripts.",
        call. = FALSE
      )
    }
    answer <- utils::askYesNo(
      sprintf("Install all %d catalogued openwashdata packages?", length(catalogued)),
      default = FALSE
    )
    if (!isTRUE(answer)) {
      message("Cancelled.")
      return(invisible(character()))
    }
    pkg <- catalogued
  } else {
    if (!is.character(pkg) || length(pkg) == 0) {
      stop("`pkg` must be a character vector of package names.", call. = FALSE)
    }
    known <- owd_packages()$pkg_name
    unknown <- setdiff(pkg, c(known, "owdata", "washr"))
    if (length(unknown) > 0) {
      stop(
        "Not in the openwashdata catalog: ", paste(unknown, collapse = ", "),
        ". See owd_packages() or owd_search().",
        call. = FALSE
      )
    }
  }
  utils::install.packages(pkg, repos = repos, ...)
  invisible(pkg)
}
