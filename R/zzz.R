# Attach behavior. owdata never attaches or installs the data packages
# it indexes; it prints a one-line catalog summary instead, plus a
# staleness hint once the installed harvest is more than eight weeks old.

owd_startup_message <- function(today = Sys.Date()) {
  cat <- owd_active_catalog()
  counts <- table(cat$packages$tier)
  msg <- sprintf(
    "owdata catalog: %d catalogued, %d candidate, %d in development (harvested %s). Try owd_search(), owd_packages(), owd_install().",
    counts[["catalogued"]], counts[["candidate"]], counts[["dev"]],
    format(cat$meta$harvest_date)
  )
  age <- as.numeric(today - cat$meta$harvest_date)
  if (is.finite(age) && age > 56) {
    msg <- paste0(
      msg,
      sprintf(" This snapshot is %d weeks old; run owd_refresh() for the latest catalog.", floor(age / 7))
    )
  }
  msg
}

.onAttach <- function(libname, pkgname) {
  msg <- tryCatch(owd_startup_message(), error = function(e) NULL)
  if (!is.null(msg)) {
    packageStartupMessage(msg)
  }
}
