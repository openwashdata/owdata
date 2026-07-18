# Attach behavior (issue #6): library(owdata) must NOT attach or
# install the data packages. One startup message only, mirroring the
# tidyverse attach-message pattern without the attaching. A staleness
# note is added when the installed harvest is more than eight weeks old
# so frozen installs do not silently serve an outdated catalog.

.onAttach <- function(libname, pkgname) {
  tbl <- tryCatch(catalog_table("owd_packages"), error = function(e) NULL)
  if (is.null(tbl) || nrow(tbl) == 0) {
    packageStartupMessage(
      "owdata: the catalog has not been harvested yet. ",
      "Try owd_refresh() to fetch the published catalog."
    )
    return(invisible())
  }
  counts <- table(tbl$tier)
  harvested <- catalog_harvest_date()
  msg <- sprintf(
    "owdata catalog: %d catalogued, %d candidate, %d in development%s. Try owd_search(), owd_packages(), owd_install().",
    counts[["catalogued"]], counts[["candidate"]], counts[["dev"]],
    if (is.na(harvested)) "" else sprintf(" (harvested %s)", format(harvested))
  )
  packageStartupMessage(msg)
  if (!is.na(harvested) && Sys.Date() - harvested > 56) {
    packageStartupMessage(
      "This catalog snapshot is more than eight weeks old; ",
      "run owd_refresh() to update it without reinstalling."
    )
  }
}
