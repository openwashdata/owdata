#' Refresh the catalog from the latest published harvest
#'
#' The catalog installed with owdata is a snapshot from build time, while
#' the harvest regenerates the published catalog weekly. owd_refresh()
#' downloads the current catalog.json from the owdata repository, stores
#' it in the user cache directory and makes it the active catalog for
#' this and future sessions. On any failure (offline, malformed
#' download), the installed snapshot stays in use and the function
#' returns FALSE instead of erroring.
#'
#' @param url Source of the catalog bundle. Defaults to the published
#'   catalog.json on the owdata main branch (override with
#'   `options(owdata.catalog_url = ...)`). A local file path is also
#'   accepted, which is mainly useful for tests.
#' @param quiet Suppress progress messages.
#' @return Invisibly, TRUE if a newer catalog was installed into the
#'   cache, FALSE otherwise.
#' @export
#' @examples
#' \dontrun{
#' owd_refresh()
#' }
owd_refresh <- function(url = owd_default_catalog_url(), quiet = FALSE) {
  say <- function(...) if (!quiet) message(...)
  path <- url
  if (!file.exists(path)) {
    path <- tempfile(fileext = ".json")
    on.exit(unlink(path), add = TRUE)
    ok <- tryCatch(
      {
        utils::download.file(url, path, quiet = TRUE, mode = "wb")
        TRUE
      },
      error = function(e) FALSE,
      warning = function(w) FALSE
    )
    if (!ok) {
      say("Could not download the catalog from ", url, "; keeping the installed snapshot.")
      return(invisible(FALSE))
    }
  }
  cat <- tryCatch(owd_read_catalog_json(path), error = function(e) NULL)
  if (!owd_is_catalog(cat)) {
    say("Downloaded catalog failed validation; keeping the installed snapshot.")
    return(invisible(FALSE))
  }
  installed <- owd_installed_catalog()
  if (cat$meta$harvest_date < installed$meta$harvest_date) {
    say(
      "Published catalog (", cat$meta$harvest_date,
      ") is older than the installed snapshot (",
      installed$meta$harvest_date, "); keeping the installed snapshot."
    )
    return(invisible(FALSE))
  }
  dir.create(owd_cache_dir(), recursive = TRUE, showWarnings = FALSE)
  saveRDS(cat, owd_cache_file())
  owd_forget_catalog()
  say(
    "Catalog refreshed: harvest of ", cat$meta$harvest_date, ", ",
    nrow(cat$packages), " packages, ", nrow(cat$datasets), " datasets, ",
    nrow(cat$variables), " variables."
  )
  invisible(TRUE)
}
