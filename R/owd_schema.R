# Internal single source of truth for the catalog table schemas
# (issue #5). The harvest (data-raw/harvest.R) must produce tables that
# match these prototypes; the schema tests assert it, and the accessors
# fall back to the empty prototypes while no harvest has shipped yet.

owd_schema <- list(
  owd_packages = list(
    pkg_name = character(), title = character(), description = character(),
    version = character(),
    tier = factor(levels = c("dev", "candidate", "catalogued")),
    legacy = logical(), maintainer = character(),
    maintainer_orcid = character(), authors = character(),
    license = character(), date = as.Date(character()), doi = character(),
    cff_version = character(), url_github = character(),
    url_docs = character(), n_datasets = integer(),
    latest_release = character(), default_branch = character(),
    created_at = as.Date(character()), last_commit = as.Date(character()),
    topics = character(), has_dictionary = logical(), has_extdata = logical()
  ),
  owd_datasets = list(
    pkg_name = character(), dataset_name = character(), title = character(),
    description = character(), n_rows = integer(), n_vars = integer(),
    n_vars_dictionary = integer(), csv_url = character(),
    xlsx_url = character()
  ),
  owd_variables = list(
    pkg_name = character(), dataset_name = character(),
    variable_name = character(), variable_type = character(),
    description = character()
  )
)

empty_catalog_tbl <- function(name) {
  stopifnot(name %in% names(owd_schema))
  tibble::as_tibble(owd_schema[[name]])
}

# Returns the named catalog table. Preference order: a refreshed copy
# from owd_refresh() when it is newer than the installed data, then the
# data shipped in the installed package, then the empty prototype (the
# state before the first harvest lands).
catalog_table <- function(name) {
  refreshed <- refreshed_table(name)
  if (!is.null(refreshed)) {
    return(refreshed)
  }
  env <- new.env(parent = emptyenv())
  got <- tryCatch(
    {
      utils::data(list = name, package = "owdata", envir = env)
      get(name, envir = env)
    },
    warning = function(w) NULL,
    error = function(e) NULL
  )
  if (is.null(got)) {
    return(empty_catalog_tbl(name))
  }
  got
}

catalog_harvest_date <- function() {
  tbl <- catalog_table("owd_packages")
  harvested <- attr(tbl, "harvested")
  if (is.null(harvested)) as.Date(NA) else as.Date(harvested)
}
