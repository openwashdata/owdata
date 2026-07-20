# Harvest orchestrator: build the openwashdata catalog.
#
# Usage:
#   OWD_HARVEST_BACKEND=github Rscript data-raw/harvest.R
#   OWD_HARVEST_BACKEND=local OWD_LOCAL_ROOT=~/clones Rscript data-raw/harvest.R
#
# Backends are interchangeable (data-raw/harvest_helpers.R); columns only
# the GitHub API can supply come back NA from the local backend. Per-repo
# failures never abort the run: they accumulate in a problems table,
# printed at the end and written to data-raw/harvest_report.md. The run
# fails (non-zero exit) only if a shipped table would be empty or more
# than 10 percent of detected packages failed to parse.
#
# Outputs:
#   R/sysdata.rda                       internal catalog snapshot
#   inst/extdata/owd_{packages,datasets,variables}.{csv,xlsx}
#   inst/extdata/catalog.json           machine-readable bundle
#   data-raw/packages.json              r-universe registry draft
#   data-raw/harvest_report.md          run report incl. problems and deltas

source("R/tier_policy.R")
source("R/parsers.R")
source("R/catalog.R")
source("data-raw/harvest_helpers.R")

org <- "openwashdata"

# --- per-repo harvest -------------------------------------------------------

# Returns NULL when the repo is not a data package, otherwise a list with
# package_row, datasets, variables, problems (data.frame rows).
harvest_repo <- function(src) {
  problems <- list()
  note <- function(stage, reason) {
    problems[[length(problems) + 1]] <<- data.frame(
      repo = src$repo, stage = stage, reason = reason
    )
  }

  desc_text <- src$read_file("DESCRIPTION")
  if (is.na(desc_text)) {
    return(NULL)
  }
  desc <- owd_parse_description(desc_text)
  if (is.na(desc$package)) {
    note("fatal", "DESCRIPTION present but unparseable")
    return(list(problems = do.call(rbind, problems)))
  }

  data_files <- src$list_files("data")
  rda <- grep("\\.rda$", data_files, value = TRUE, ignore.case = TRUE)
  if (length(rda) == 0) {
    return(NULL)
  }

  cff <- owd_parse_cff(src$read_file("CITATION.cff"))
  version_norm <- owd_normalize_version(desc$version)
  if (!is.na(desc$version) && !identical(desc$version, version_norm)) {
    note("warn", paste0("normalized malformed version '", desc$version, "'"))
  }
  if (!is.na(version_norm) && !owd_version_is_valid(version_norm)) {
    note("warn", paste0("unparseable version '", desc$version, "', tier falls back to dev"))
  }
  tier_info <- owd_assign_tier(desc$version, cff$doi)
  if (!is.na(cff$version) && !is.na(version_norm) &&
      !identical(owd_normalize_version(cff$version), version_norm)) {
    note("warn", sprintf(
      "version drift: DESCRIPTION %s vs CITATION.cff %s", version_norm, cff$version
    ))
  }

  url_github <- paste0("https://github.com/", org, "/", src$repo)
  if (!is.na(desc$url) && !grepl(url_github, desc$url, fixed = TRUE)) {
    note("warn", paste0("DESCRIPTION URL does not mention ", url_github))
  }

  dict_text <- src$read_file("data-raw/dictionary.csv")
  extdata <- src$list_files("inst/extdata")

  package_row <- tibble::tibble(
    pkg_name = desc$package,
    title = desc$title,
    description = desc$description,
    version = version_norm,
    tier = tier_info$tier,
    legacy = tier_info$legacy,
    maintainer = desc$maintainer,
    maintainer_orcid = desc$maintainer_orcid,
    authors = desc$authors,
    license = desc$license,
    date = desc$date,
    doi = cff$doi,
    cff_version = cff$version,
    url_github = url_github,
    url_docs = paste0("https://openwashdata.github.io/", desc$package, "/"),
    n_datasets = length(rda),
    latest_release = src$meta$latest_release,
    default_branch = src$meta$default_branch,
    created_at = as.Date(src$meta$created_at),
    last_commit = as.Date(src$meta$pushed_at),
    topics = src$meta$topics,
    has_dictionary = !is.na(dict_text),
    has_extdata = length(extdata) > 0
  )

  datasets <- NULL
  variables <- NULL
  if (as.character(tier_info$tier) %in% c("candidate", "catalogued")) {
    detail <- harvest_detail(src, desc$package, rda, dict_text, extdata, note)
    datasets <- detail$datasets
    variables <- detail$variables
  }

  list(
    package_row = package_row,
    datasets = datasets,
    variables = variables,
    problems = if (length(problems) > 0) do.call(rbind, problems) else NULL
  )
}

# Dataset- and variable-level detail, harvested only for candidate and
# catalogued packages.
harvest_detail <- function(src, pkg_name, rda, dict_text, extdata, note) {
  ds_names <- sub("\\.rda$", "", rda, ignore.case = TRUE)

  # Roxygen data docs from every R source file.
  r_files <- grep("\\.[Rr]$", src$list_files("R"), value = TRUE)
  docs <- lapply(r_files, function(f) {
    owd_parse_data_docs(src$read_file(file.path("R", f)))
  })
  docs <- do.call(rbind, c(docs, list(owd_parse_data_docs(NA_character_))))
  docs <- docs[!duplicated(docs$dataset_name), , drop = FALSE]

  # Dictionary, with git-lfs refetch through the media endpoint.
  dict <- owd_parse_dictionary(dict_text)
  if (identical(dict$status, "lfs_pointer")) {
    dict <- owd_parse_dictionary(src$read_file_media("data-raw/dictionary.csv"))
    if (!identical(dict$status, "ok")) {
      note("warn", "dictionary.csv is a git-lfs pointer and the media fetch failed")
    }
  }
  dict_rows <- NULL
  if (identical(dict$status, "ok")) {
    dict_rows <- dict$data
    dict_rows$dataset_name <- sub("\\.rda$", "", dict_rows$file_name, ignore.case = TRUE)
    if (identical(dict$schema, "two_column")) {
      if (length(ds_names) == 1) {
        dict_rows$dataset_name <- ds_names
      } else {
        note("warn", "two-column dictionary in a multi-dataset package; variables not attributed")
        dict_rows$dataset_name <- NA_character_
      }
    }
    unknown <- setdiff(stats::na.omit(unique(dict_rows$dataset_name)), ds_names)
    if (length(unknown) > 0) {
      note("warn", paste(
        "dictionary references file_name(s) with no matching data/*.rda:",
        paste(unknown, collapse = ", ")
      ))
    }
  } else if (!is.na(dict_text) && length(dict$notes) > 0) {
    note("warn", paste("dictionary.csv:", paste(dict$notes, collapse = "; ")))
  }

  n_vars_dict <- if (!is.null(dict_rows)) table(dict_rows$dataset_name) else table(character())
  doc_idx <- match(ds_names, docs$dataset_name)
  branch <- src$meta$default_branch
  file_url <- function(name, ext) {
    file <- paste0(name, ext)
    ifelse(
      file %in% extdata & !is.na(branch),
      paste0(
        "https://raw.githubusercontent.com/", org, "/", src$repo, "/",
        branch, "/inst/extdata/", file
      ),
      NA_character_
    )
  }

  datasets <- tibble::tibble(
    pkg_name = pkg_name,
    dataset_name = ds_names,
    title = docs$title[doc_idx],
    description = docs$description[doc_idx],
    n_rows = docs$n_rows[doc_idx],
    n_vars = docs$n_vars[doc_idx],
    n_vars_dictionary = as.integer(ifelse(
      ds_names %in% names(n_vars_dict), n_vars_dict[ds_names], NA_integer_
    )),
    csv_url = file_url(ds_names, ".csv"),
    xlsx_url = file_url(ds_names, ".xlsx")
  )

  variables <- NULL
  if (!is.null(dict_rows) && nrow(dict_rows) > 0) {
    variables <- tibble::tibble(
      pkg_name = pkg_name,
      dataset_name = dict_rows$dataset_name,
      variable_name = dict_rows$variable_name,
      variable_type = dict_rows$variable_type,
      description = dict_rows$description
    )
  }
  list(datasets = datasets, variables = variables)
}

# --- run --------------------------------------------------------------------

backend <- Sys.getenv("OWD_HARVEST_BACKEND", unset = "github")
message("Harvest backend: ", backend)

exclude <- utils::read.csv("data-raw/exclude_repos.csv", colClasses = "character")
overrides <- utils::read.csv("data-raw/tier_overrides.csv", colClasses = "character")

if (backend == "local") {
  root <- Sys.getenv("OWD_LOCAL_ROOT")
  stopifnot(nzchar(root), dir.exists(root))
  paths <- owd_local_repos(root)
  paths <- paths[!basename(paths) %in% exclude$repo_name]
  sources <- paths
  make_source <- owd_local_source
} else {
  listing <- owd_github_repos(org)
  message(length(listing$active), " active repos, ", length(listing$archived), " archived (skipped)")
  sources <- setdiff(listing$active, exclude$repo_name)
  make_source <- function(repo) owd_github_source(repo, org)
}

results <- vector("list", length(sources))
problems <- list()
for (i in seq_along(sources)) {
  id <- basename(sources[[i]])
  results[[i]] <- tryCatch(
    harvest_repo(make_source(sources[[i]])),
    error = function(e) {
      list(problems = data.frame(repo = id, stage = "fatal", reason = conditionMessage(e)))
    }
  )
}

pick <- function(field) {
  parts <- lapply(results, function(r) r[[field]])
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0) NULL else do.call(rbind, parts)
}

packages <- pick("package_row")
datasets <- pick("datasets")
variables <- pick("variables")
problems <- pick("problems")
if (is.null(problems)) {
  problems <- data.frame(repo = character(), stage = character(), reason = character())
}

stopifnot(!is.null(packages))
packages <- packages[order(packages$pkg_name), , drop = FALSE]
tiers <- owd_apply_tier_overrides(
  data.frame(tier = packages$tier, legacy = packages$legacy),
  packages$pkg_name, overrides
)
packages$tier <- tiers$tier
packages$legacy <- tiers$legacy
if (!is.null(datasets)) datasets <- datasets[order(datasets$pkg_name, datasets$dataset_name), , drop = FALSE]
if (!is.null(variables)) variables <- variables[order(variables$pkg_name, variables$dataset_name), , drop = FALSE]

# --- gates ------------------------------------------------------------------

n_detected <- nrow(packages) + length(unique(problems$repo[problems$stage == "fatal"]))
n_fatal <- length(unique(problems$repo[problems$stage == "fatal"]))
message(sprintf(
  "Detected %d data packages (%d fatal failures), %d datasets, %d variables",
  n_detected, n_fatal,
  if (is.null(datasets)) 0 else nrow(datasets),
  if (is.null(variables)) 0 else nrow(variables)
))
if (is.null(datasets) || is.null(variables) ||
    nrow(packages) == 0 || nrow(datasets) == 0 || nrow(variables) == 0) {
  stop("A shipped table would be empty; refusing to write the catalog.")
}
if (n_fatal / n_detected > 0.10) {
  stop(sprintf(
    "%d of %d detected packages failed to parse (over 10 percent); refusing to write the catalog.",
    n_fatal, n_detected
  ))
}

# --- deltas against the previous committed run ------------------------------

deltas <- character()
prev_path <- "inst/extdata/owd_packages.csv"
if (file.exists(prev_path)) {
  prev <- utils::read.csv(prev_path, colClasses = "character")
  na_rate <- function(df, col) {
    if (is.null(df[[col]])) 1 else mean(is.na(df[[col]]) | df[[col]] == "")
  }
  for (col in c("doi", "description", "title", "maintainer")) {
    old_rate <- na_rate(prev, col)
    new_rate <- mean(is.na(packages[[col]]))
    if (new_rate > old_rate + 0.01) {
      deltas <- c(deltas, sprintf(
        "NA rate for %s rose from %.0f%% to %.0f%%", col, 100 * old_rate, 100 * new_rate
      ))
    }
  }
  both <- intersect(prev$pkg_name, packages$pkg_name)
  old_tier <- prev$tier[match(both, prev$pkg_name)]
  new_tier <- as.character(packages$tier[match(both, packages$pkg_name)])
  moved <- both[old_tier != new_tier]
  for (p in moved) {
    deltas <- c(deltas, sprintf(
      "tier change: %s %s -> %s", p,
      old_tier[match(p, both)], new_tier[match(p, both)]
    ))
  }
  gone <- setdiff(prev$pkg_name, packages$pkg_name)
  if (length(gone) > 0) {
    deltas <- c(deltas, paste("packages dropped from catalog:", paste(gone, collapse = ", ")))
  }
}

# --- assemble and write -----------------------------------------------------

meta <- list(
  harvested_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  harvest_date = Sys.Date(),
  policy_version = owd_policy_version(),
  backend = backend,
  org = org,
  n_repos_scanned = length(sources),
  n_problems = nrow(problems)
)
owd_catalog <- list(
  meta = meta,
  packages = tibble::as_tibble(packages),
  datasets = tibble::as_tibble(datasets),
  variables = tibble::as_tibble(variables),
  index = owd_build_index(packages, datasets, variables)
)
stopifnot(owd_is_catalog(owd_catalog))

save(owd_catalog, file = "R/sysdata.rda", compress = "xz", version = 2)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
tables <- list(
  owd_packages = owd_catalog$packages,
  owd_datasets = owd_catalog$datasets,
  owd_variables = owd_catalog$variables
)
for (name in names(tables)) {
  utils::write.csv(
    tables[[name]], file.path("inst/extdata", paste0(name, ".csv")),
    row.names = FALSE, na = "", fileEncoding = "UTF-8"
  )
  if (requireNamespace("writexl", quietly = TRUE)) {
    writexl::write_xlsx(
      stats::setNames(list(tables[[name]]), name),
      file.path("inst/extdata", paste0(name, ".xlsx"))
    )
  }
}
owd_write_catalog_json(owd_catalog, "inst/extdata/catalog.json")

# r-universe registry draft. washr and owdata are hard-coded on purpose:
# the custom registry supersedes the auto-generated CRAN registry, so a
# generated file that ever omitted washr would silently drop it from
# https://openwashdata.r-universe.dev (openwashdata/owdata#8).
registry <- unique(c(packages$pkg_name, "washr", "owdata"))
registry <- sort(registry)
packages_json <- data.frame(
  package = registry,
  url = paste0("https://github.com/", org, "/", registry)
)
writeLines(
  jsonlite::toJSON(packages_json, pretty = TRUE),
  "data-raw/packages.json"
)

# --- report -----------------------------------------------------------------

report <- c(
  "# Harvest report", "",
  paste0("Run: ", meta$harvested_at, " (backend: ", backend, ")"), "",
  sprintf(
    "Packages: %d (%s). Datasets: %d. Variables: %d.",
    nrow(packages),
    paste(sprintf("%s %d", names(table(packages$tier)), table(packages$tier)), collapse = ", "),
    nrow(datasets), nrow(variables)
  ), "",
  "## Deltas since previous committed run", "",
  if (length(deltas) > 0) paste0("- ", deltas) else "None.", "",
  "## Problems", "",
  if (nrow(problems) > 0) {
    sprintf("- %s [%s]: %s", problems$repo, problems$stage, problems$reason)
  } else {
    "None."
  }
)
writeLines(report, "data-raw/harvest_report.md")

message(paste(report, collapse = "\n"))
if (length(deltas) > 0) {
  message("DELTA WARNINGS PRESENT: review data-raw/harvest_report.md before trusting this run.")
}
message("Harvest complete.")
