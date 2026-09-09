# Attach behaviour. owdata never attaches or installs the packages it
# indexes; it prints one line naming the catalog and its harvest date.
# That date is the whole staleness signal: there is no refresh function
# and no cache (dev/decisions-2026-09.md, section 2).

owd_startup_message <- function() {
  cat <- owd_active_catalog()
  sprintf(
    "owdata catalog: %d published packages, %d datasets, %d variables (harvested %s). Try owd_search(), owd_packages(), owd_install().",
    sum(cat$packages$published, na.rm = TRUE),
    nrow(cat$datasets),
    nrow(cat$variables),
    format(cat$meta$harvest_date)
  )
}

.onAttach <- function(libname, pkgname) {
  msg <- tryCatch(owd_startup_message(), error = function(e) NULL)
  if (!is.null(msg)) {
    packageStartupMessage(msg)
  }
}
