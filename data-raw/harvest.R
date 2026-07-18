# Harvest orchestrator (issue #4): produces the catalog from the
# openwashdata GitHub org, with two interchangeable backends.
#
#   harvest_local(root)  identical parsing against local clones, for
#                        development and tests; GitHub-API-only columns
#                        come back NA
#   harvest_github()     one paginated repo list via the gh package,
#                        then per-repo raw fetches; roughly 5-7 requests
#                        per repo, far under the API limit
#
# Run locally from the package root:
#   Rscript data-raw/harvest.R            # local backend against ../
#   HARVEST_BACKEND=github Rscript data-raw/harvest.R
#
# Error tolerance: per-repo tryCatch; failures accumulate in a problems
# tibble printed at the end. The run only errors (failing CI) if any
# shipped table would be empty or more than 10 percent of detected
# packages failed to parse. In addition (premortem finding R3), the run
# compares itself against the previously committed CSV exports and
# warns loudly on week-over-week regressions: schema tests alone assert
# names and types, never values, so content-level drift must be
# surfaced here.

source(file.path("data-raw", "harvest_helpers.R"))
source(file.path("data-raw", "tier_policy.R"))

HARVEST_ORG <- "openwashdata"
FAILURE_THRESHOLD <- 0.10

read_exclusions <- function(path = file.path("data-raw", "exclude_repos.csv")) {
  if (!file.exists(path)) {
    return(character())
  }
  utils::read.csv(path, stringsAsFactors = FALSE)$repo
}

# Package detection (positive rule, denylist as backstop): not archived,
# not excluded, root DESCRIPTION with a Package field, at least one
# data/*.rda.
is_data_package <- function(path) {
  file.exists(file.path(path, "DESCRIPTION")) &&
    length(list.files(file.path(path, "data"), pattern = "\\.rda$")) > 0
}

# ---- local backend -----------------------------------------------------

harvest_one_local <- function(path) {
  pkg_dir <- basename(path)
  desc <- parse_description(file.path(path, "DESCRIPTION"))
  if (is.null(desc) || is.na(desc$package)) {
    stop("DESCRIPTION unparseable")
  }

  rda <- list.files(file.path(path, "data"), pattern = "\\.rda$")
  datasets <- sub("\\.rda$", "", rda)
  single <- if (length(datasets) == 1) datasets[[1]] else NA_character_

  cff_path <- file.path(path, "CITATION.cff")
  cff <- if (file.exists(cff_path)) {
    parse_cff(cff_path)
  } else {
    list(doi = NA_character_, version = NA_character_)
  }

  dict_path <- file.path(path, "data-raw", "dictionary.csv")
  dict <- if (file.exists(dict_path)) {
    parse_dictionary(dict_path, single_dataset = single)
  } else {
    list(data = NULL, schema = NA_character_, problem = "no dictionary.csv")
  }

  roxy <- do.call(rbind, c(
    lapply(
      list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE),
      parse_roxygen_format
    ),
    make.row.names = FALSE
  ))

  extdata <- list.files(file.path(path, "inst", "extdata"))

  list(
    pkg_name = desc$package,
    desc = desc,
    cff = cff,
    dict = dict,
    roxy = roxy,
    datasets = datasets,
    has_dictionary = file.exists(dict_path),
    has_extdata = length(extdata) > 0,
    extdata = extdata,
    github = list(
      latest_release = NA_character_, default_branch = NA_character_,
      created_at = as.Date(NA), last_commit = as.Date(NA),
      topics = NA_character_
    )
  )
}

harvest_local <- function(root) {
  dirs <- list.dirs(root, recursive = FALSE)
  dirs <- dirs[!basename(dirs) %in% read_exclusions()]
  dirs <- Filter(is_data_package, dirs)
  collect(dirs, harvest_one_local, id = basename)
}

# ---- github backend ----------------------------------------------------

# Per repo: raw.githubusercontent fetches of DESCRIPTION,
# data-raw/dictionary.csv, CITATION.cff (default branch) plus
# contents-API listings of data/, R/, inst/extdata/. The built-in
# GITHUB_TOKEN suffices for public repos.
#
# Review verification (premortem finding R2, promoted from "optional
# later hardening"): for every candidate or catalogued package outside
# the grandfather rule, the backend also counts closed pkgreview issues;
# a catalogued package without a completed review is flagged in the
# problems tibble instead of silently trusted.
harvest_github <- function(org = HARVEST_ORG) {
  if (!requireNamespace("gh", quietly = TRUE)) {
    stop("the github backend needs the gh package")
  }
  repos <- gh::gh(
    "GET /orgs/{org}/repos",
    org = org, per_page = 100, .limit = Inf
  )
  repos <- Filter(function(r) !isTRUE(r$archived), repos)
  repos <- repos[!vapply(repos, function(r) r$name, "") %in% read_exclusions()]

  fetch_raw <- function(repo, branch, file) {
    url <- sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/%s",
      org, repo, branch, file
    )
    tryCatch(
      paste(readLines(url, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
      error = function(e) NULL,
      warning = function(w) NULL
    )
  }

  harvest_one_github <- function(r) {
    branch <- r$default_branch %||% "main"
    desc_txt <- fetch_raw(r$name, branch, "DESCRIPTION")
    if (is.null(desc_txt)) stop("no root DESCRIPTION")
    desc <- parse_description(desc_txt)
    if (is.null(desc) || is.na(desc$package)) stop("DESCRIPTION unparseable")

    listing <- function(dir) {
      tryCatch(
        vapply(
          gh::gh(
            "GET /repos/{org}/{repo}/contents/{path}",
            org = org, repo = r$name, path = dir
          ),
          function(x) x$name, character(1)
        ),
        error = function(e) character()
      )
    }
    rda <- grep("\\.rda$", listing("data"), value = TRUE)
    if (length(rda) == 0) stop("no data/*.rda; not a data package")
    datasets <- sub("\\.rda$", "", rda)
    single <- if (length(datasets) == 1) datasets[[1]] else NA_character_

    dict_txt <- fetch_raw(r$name, branch, "data-raw/dictionary.csv")
    dict <- if (is.null(dict_txt)) {
      list(data = NULL, schema = NA_character_, problem = "no dictionary.csv")
    } else {
      parse_dictionary(dict_txt, single_dataset = single)
    }

    cff_txt <- fetch_raw(r$name, branch, "CITATION.cff")
    cff <- if (is.null(cff_txt)) {
      list(doi = NA_character_, version = NA_character_)
    } else {
      parse_cff(cff_txt)
    }

    r_files <- grep("\\.R$", listing("R"), value = TRUE)
    roxy <- do.call(rbind, c(
      lapply(r_files, function(f) {
        txt <- fetch_raw(r$name, branch, paste0("R/", f))
        if (is.null(txt)) NULL else parse_roxygen_format(txt)
      }),
      make.row.names = FALSE
    ))

    release <- tryCatch(
      gh::gh(
        "GET /repos/{org}/{repo}/releases/latest",
        org = org, repo = r$name
      )$tag_name,
      error = function(e) NA_character_
    )

    extdata <- listing("inst/extdata")

    list(
      pkg_name = desc$package,
      desc = desc, cff = cff, dict = dict, roxy = roxy,
      datasets = datasets,
      has_dictionary = !is.null(dict_txt),
      has_extdata = length(extdata) > 0,
      extdata = extdata,
      github = list(
        latest_release = release %||% NA_character_,
        default_branch = branch,
        created_at = as.Date(substr(r$created_at %||% NA, 1, 10)),
        last_commit = as.Date(substr(r$pushed_at %||% NA, 1, 10)),
        topics = paste(unlist(r$topics), collapse = "; ")
      )
    )
  }

  collect(repos, harvest_one_github, id = function(r) r$name)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Shared per-item error accumulation: failures are data, not errors.
collect <- function(items, fn, id) {
  results <- list()
  problems <- list()
  for (item in items) {
    name <- id(item)
    out <- tryCatch(fn(item), error = function(e) e)
    if (inherits(out, "error")) {
      problems[[length(problems) + 1]] <- data.frame(
        repo = name, problem = conditionMessage(out),
        stringsAsFactors = FALSE
      )
    } else {
      results[[length(results) + 1]] <- out
    }
  }
  list(
    results = results,
    problems = if (length(problems) > 0) {
      do.call(rbind, problems)
    } else {
      data.frame(repo = character(), problem = character())
    }
  )
}

# ---- assembly ----------------------------------------------------------

assemble_catalog <- function(harvest) {
  results <- harvest$results
  overrides <- read_tier_overrides()

  version <- vapply(results, function(x) x$desc$version %||% NA_character_, "")
  doi <- vapply(results, function(x) x$cff$doi %||% NA_character_, "")
  pkg_name <- vapply(results, function(x) x$pkg_name, "")
  tiers <- apply_tier_overrides(pkg_name, assign_tier(version, doi), overrides)

  owd_packages <- tibble::tibble(
    pkg_name = pkg_name,
    title = vapply(results, function(x) x$desc$title %||% NA_character_, ""),
    description = vapply(results, function(x) x$desc$description %||% NA_character_, ""),
    version = normalize_version(version),
    tier = tiers$tier,
    legacy = tiers$legacy,
    maintainer = vapply(results, function(x) x$desc$maintainer, ""),
    maintainer_orcid = vapply(results, function(x) x$desc$maintainer_orcid, ""),
    authors = vapply(results, function(x) x$desc$authors, ""),
    license = vapply(results, function(x) x$desc$license %||% NA_character_, ""),
    date = as.Date(vapply(
      results, function(x) as.character(x$desc$date %||% NA), ""
    )),
    doi = vapply(results, function(x) x$cff$doi %||% NA_character_, ""),
    cff_version = vapply(results, function(x) x$cff$version %||% NA_character_, ""),
    url_github = paste0("https://github.com/openwashdata/", pkg_name),
    url_docs = paste0("https://openwashdata.github.io/", pkg_name, "/"),
    n_datasets = vapply(results, function(x) length(x$datasets), 1L),
    latest_release = vapply(results, function(x) x$github$latest_release, ""),
    default_branch = vapply(results, function(x) x$github$default_branch, ""),
    created_at = as.Date(vapply(
      results, function(x) as.character(x$github$created_at), ""
    )),
    last_commit = as.Date(vapply(
      results, function(x) as.character(x$github$last_commit), ""
    )),
    topics = vapply(results, function(x) x$github$topics %||% NA_character_, ""),
    has_dictionary = vapply(results, function(x) x$has_dictionary, TRUE),
    has_extdata = vapply(results, function(x) x$has_extdata, TRUE)
  )

  # Dataset- and variable-level detail only for candidate and catalogued
  # tiers (issue #5, tier scoping rationale).
  detail <- !is.na(tiers$tier) & tiers$tier %in% c("candidate", "catalogued")

  dataset_rows <- lapply(which(detail), function(i) {
    x <- results[[i]]
    roxy <- x$roxy
    dict <- x$dict$data
    lapply(x$datasets, function(ds) {
      doc <- if (!is.null(roxy) && nrow(roxy) > 0) {
        roxy[roxy$dataset_name == ds, , drop = FALSE]
      } else {
        NULL
      }
      n_dict <- if (!is.null(dict)) {
        sum(
          sub("\\.rda$", "", dict$file_name) == ds |
            dict$file_name == paste0(ds, ".rda"),
          na.rm = TRUE
        )
      } else {
        NA_integer_
      }
      csv <- paste0(ds, ".csv") %in% x$extdata
      xlsx <- paste0(ds, ".xlsx") %in% x$extdata
      raw_base <- sprintf(
        "https://raw.githubusercontent.com/openwashdata/%s/%s/inst/extdata/",
        x$pkg_name, x$github$default_branch %||% "main"
      )
      tibble::tibble(
        pkg_name = x$pkg_name,
        dataset_name = ds,
        title = if (!is.null(doc) && nrow(doc) > 0) doc$title[[1]] else NA_character_,
        description = if (!is.null(doc) && nrow(doc) > 0) doc$description[[1]] else NA_character_,
        n_rows = if (!is.null(doc) && nrow(doc) > 0) doc$n_rows[[1]] else NA_integer_,
        n_vars = if (!is.null(doc) && nrow(doc) > 0) doc$n_vars[[1]] else NA_integer_,
        n_vars_dictionary = n_dict,
        csv_url = if (csv) paste0(raw_base, ds, ".csv") else NA_character_,
        xlsx_url = if (xlsx) paste0(raw_base, ds, ".xlsx") else NA_character_
      )
    })
  })
  owd_datasets <- do.call(rbind, unlist(dataset_rows, recursive = FALSE))
  if (is.null(owd_datasets)) {
    owd_datasets <- tibble::tibble(
      pkg_name = character(), dataset_name = character(), title = character(),
      description = character(), n_rows = integer(), n_vars = integer(),
      n_vars_dictionary = integer(), csv_url = character(), xlsx_url = character()
    )
  }

  variable_rows <- lapply(which(detail), function(i) {
    x <- results[[i]]
    dict <- x$dict$data
    if (is.null(dict) || nrow(dict) == 0) {
      return(NULL)
    }
    tibble::tibble(
      pkg_name = x$pkg_name,
      dataset_name = sub("\\.rda$", "", dict$file_name),
      variable_name = dict$variable_name,
      variable_type = dict$variable_type,
      description = dict$description
    )
  })
  owd_variables <- do.call(rbind, Filter(Negate(is.null), variable_rows))
  if (is.null(owd_variables)) {
    owd_variables <- tibble::tibble(
      pkg_name = character(), dataset_name = character(),
      variable_name = character(), variable_type = character(),
      description = character()
    )
  }

  list(
    owd_packages = owd_packages,
    owd_datasets = owd_datasets,
    owd_variables = owd_variables,
    problems = harvest$problems
  )
}

# ---- content-level regression check (premortem finding R3) -------------

# Schema tests assert names and types, never values, so a run that
# half-parses packages into NA DOIs would otherwise ship silently. This
# compares against the previously committed export and reports every
# regression; run with strict = TRUE (the default in CI) to fail on them.
check_against_previous <- function(catalog, strict = TRUE,
                                   previous_csv = file.path("inst", "extdata", "owd_packages.csv")) {
  if (!file.exists(previous_csv)) {
    return(invisible(TRUE))
  }
  prev <- utils::read.csv(previous_csv, stringsAsFactors = FALSE)
  cur <- catalog$owd_packages
  msgs <- character()

  if (nrow(cur) < nrow(prev)) {
    msgs <- c(msgs, sprintf(
      "package count dropped from %d to %d", nrow(prev), nrow(cur)
    ))
  }
  na_rate <- function(df, col) {
    if (!col %in% names(df) || nrow(df) == 0) {
      return(0)
    }
    mean(is.na(df[[col]]) | df[[col]] == "")
  }
  for (col in c("doi", "description", "tier")) {
    if (na_rate(cur, col) > na_rate(prev, col) + 1e-9) {
      msgs <- c(msgs, sprintf(
        "NA rate for %s rose from %.0f%% to %.0f%%",
        col, 100 * na_rate(prev, col), 100 * na_rate(cur, col)
      ))
    }
  }
  if (nrow(catalog$problems) > 0) {
    msgs <- c(msgs, sprintf(
      "%d package(s) in the problems tibble: %s",
      nrow(catalog$problems), paste(catalog$problems$repo, collapse = ", ")
    ))
  }

  if (length(msgs) > 0) {
    txt <- paste("harvest content regression:", paste(msgs, collapse = "; "))
    if (strict) stop(txt) else warning(txt)
  }
  invisible(length(msgs) == 0)
}

# ---- outputs -----------------------------------------------------------

write_outputs <- function(catalog) {
  harvested <- Sys.Date()
  for (nm in c("owd_packages", "owd_datasets", "owd_variables")) {
    attr(catalog[[nm]], "harvested") <- harvested
  }

  owd_packages <- catalog$owd_packages
  owd_datasets <- catalog$owd_datasets
  owd_variables <- catalog$owd_variables
  usethis::use_data(owd_packages, owd_datasets, owd_variables, overwrite = TRUE)

  dir.create(file.path("inst", "extdata"), recursive = TRUE, showWarnings = FALSE)
  for (nm in c("owd_packages", "owd_datasets", "owd_variables")) {
    utils::write.csv(
      catalog[[nm]], file.path("inst", "extdata", paste0(nm, ".csv")),
      row.names = FALSE, fileEncoding = "UTF-8"
    )
  }
  if (requireNamespace("writexl", quietly = TRUE)) {
    writexl::write_xlsx(
      list(
        owd_packages = catalog$owd_packages,
        owd_datasets = catalog$owd_datasets,
        owd_variables = catalog$owd_variables
      ),
      file.path("inst", "extdata", "owd_catalog.xlsx")
    )
  }

  jsonlite::write_json(
    list(
      harvested = as.character(harvested),
      policy_version = POLICY_VERSION,
      owd_packages = catalog$owd_packages,
      owd_datasets = catalog$owd_datasets,
      owd_variables = catalog$owd_variables
    ),
    file.path("inst", "extdata", "catalog.json"),
    auto_unbox = TRUE, na = "null", Date = "ISO8601"
  )

  # Regenerated on every run so the registry draft cannot drift from the
  # catalog; washr and owdata are included by construction.
  write_registry(catalog$owd_packages$pkg_name)
}

# ---- entry point -------------------------------------------------------

if (sys.nframe() == 0) {
  backend <- Sys.getenv("HARVEST_BACKEND", "local")
  root <- Sys.getenv("HARVEST_ROOT", "..")

  harvest <- if (backend == "github") harvest_github() else harvest_local(root)

  n_ok <- length(harvest$results)
  n_bad <- nrow(harvest$problems)
  message(sprintf("harvested %d packages, %d problems", n_ok, n_bad))
  if (n_bad > 0) {
    print(harvest$problems)
  }
  if (n_ok == 0) {
    stop("no packages harvested; refusing to ship empty tables")
  }
  if (n_bad / (n_ok + n_bad) > FAILURE_THRESHOLD) {
    stop(sprintf(
      "%.0f%% of detected packages failed to parse (threshold %.0f%%)",
      100 * n_bad / (n_ok + n_bad), 100 * FAILURE_THRESHOLD
    ))
  }

  catalog <- assemble_catalog(harvest)
  check_against_previous(
    catalog,
    strict = !identical(Sys.getenv("HARVEST_STRICT"), "false")
  )
  write_outputs(catalog)
  message("harvest complete")
}
