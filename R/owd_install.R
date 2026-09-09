#' Install openwashdata packages from the openwashdata R-universe
#'
#' A thin wrapper around [utils::install.packages()] that points at
#' <https://openwashdata.r-universe.dev> (with CRAN as fallback for
#' dependencies).
#'
#' @param pkg Character vector of package names to install. NULL (the
#'   default) installs every published package after an interactive
#'   confirmation showing the count; in non-interactive sessions NULL is
#'   an error, so scripts must name packages explicitly.
#' @param ... Passed on to [utils::install.packages()].
#' @returns Invisibly, the character vector of package names requested.
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
    published <- owd_packages(published = TRUE)$pkg_name
    if (length(published) == 0) {
      stop("The catalog lists no published packages yet.", call. = FALSE)
    }
    if (!interactive()) {
      stop(
        "pkg = NULL would install all ", length(published),
        " published packages. Name packages explicitly in scripts.",
        call. = FALSE
      )
    }
    answer <- utils::askYesNo(
      sprintf("Install all %d published openwashdata packages?", length(published)),
      default = FALSE
    )
    if (!isTRUE(answer)) {
      message("Cancelled.")
      return(invisible(character()))
    }
    pkg <- published
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
