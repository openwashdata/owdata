# Generate data-raw/upstream_fixes.md: the per-repo defect list that
# seeds the migration campaign (openwashdata/owdata#10). Everything is
# derived from the harvested catalog plus, when OWD_LOCAL_ROOT points at
# local clones, a direct inspection of each repo's dictionary.csv, so
# the list can be regenerated after any harvest.
#
# Usage:
#   OWD_LOCAL_ROOT=~/clones Rscript data-raw/upstream_fixes.R

source("R/tier_policy.R")
source("R/parsers.R")

load("R/sysdata.rda")
pk <- owd_catalog$packages
ds <- owd_catalog$datasets

fixes <- list()
add <- function(repo, file, defect, fix) {
  fixes[[length(fixes) + 1]] <<- data.frame(
    repo = repo, file = file, defect = defect, fix = fix
  )
}

# --- from the catalog -------------------------------------------------------

for (i in seq_len(nrow(pk))) {
  p <- pk[i, ]

  # Malformed version strings (the normalized value differs from raw is
  # not visible post-harvest, so re-check the leading-v case via cff).
  if (!is.na(p$version) && !owd_version_is_valid(p$version)) {
    add(p$pkg_name, "DESCRIPTION", paste0("Version '", p$version, "' does not parse"),
        "Set a valid version, for example 1.0.0")
  }

  # DESCRIPTION vs CITATION.cff version drift.
  if (!is.na(p$cff_version) && !is.na(p$version) &&
      !identical(owd_normalize_version(p$cff_version), p$version)) {
    add(p$pkg_name, "CITATION.cff",
        sprintf("version %s disagrees with DESCRIPTION %s", p$cff_version, p$version),
        "Run washr::update_citation() after the next version bump")
  }

  # Candidate or catalogued without a dictionary: variables missing from
  # the catalog entirely.
  if (p$tier %in% c("candidate", "catalogued") && !p$has_dictionary) {
    add(p$pkg_name, "data-raw/dictionary.csv", "file missing in a reviewed-tier package",
        "Add the five-column dictionary (washr template)")
  }

  # DESCRIPTION URL not pointing at the repo.
  if (!is.na(p$url_github)) {
    # url mismatches were recorded at harvest time; recompute cheaply is
    # not possible without the raw DESCRIPTION, so this check lives in
    # harvest_report.md and is merged below.
  }
}

# @format dimensions disagreeing with the dictionary row count.
bad <- ds[!is.na(ds$n_vars) & !is.na(ds$n_vars_dictionary) &
            ds$n_vars != ds$n_vars_dictionary, ]
for (i in seq_len(nrow(bad))) {
  b <- bad[i, ]
  add(b$pkg_name, paste0("R/", b$dataset_name, ".R and data-raw/dictionary.csv"),
      sprintf("@format says %d variables, dictionary lists %d for %s",
              b$n_vars, b$n_vars_dictionary, b$dataset_name),
      "Reconcile the documentation with the dictionary")
}

# Datasets in reviewed tiers with unparseable or missing @format.
nofmt <- ds[is.na(ds$n_rows) | is.na(ds$n_vars), ]
for (i in seq_len(nrow(nofmt))) {
  b <- nofmt[i, ]
  add(b$pkg_name, paste0("R/", b$dataset_name, ".R"),
      paste0("no parseable @format dimensions for ", b$dataset_name),
      "Add '@format A tibble with N rows and M variables'")
}

# --- from local clones (dictionary pathologies, encoding) -------------------

root <- Sys.getenv("OWD_LOCAL_ROOT", unset = "")
if (nzchar(root) && dir.exists(root)) {
  for (path in list.dirs(root, recursive = FALSE)) {
    repo <- basename(path)
    if (!repo %in% pk$pkg_name) next
    f <- file.path(path, "data-raw", "dictionary.csv")
    if (!file.exists(f)) next
    raw <- readBin(f, "raw", n = file.size(f))
    txt <- rawToChar(raw)

    if (!all(validUTF8(txt))) {
      add(repo, "data-raw/dictionary.csv", "file is not UTF-8 encoded (latin1)",
          "Re-save the file as UTF-8")
      txt <- iconv(txt, from = "latin1", to = "UTF-8")
    } else {
      Encoding(txt) <- "UTF-8"
    }
    if (grepl("^version https://git-lfs", txt)) {
      add(repo, "data-raw/dictionary.csv", "stored as a git-lfs pointer",
          "Untrack the file from git-lfs and commit the plain CSV")
      next
    }
    if (length(raw) >= 3 && identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
      add(repo, "data-raw/dictionary.csv", "starts with a UTF-8 BOM",
          "Re-save without BOM")
    }
    header <- strsplit(txt, "\r?\n")[[1]][1]
    std <- "directory,file_name,variable_name,variable_type,description"
    header_clean <- sub("^\ufeff", "", header)
    if (!identical(header_clean, std)) {
      parsed <- owd_parse_dictionary(txt)
      kind <- if (identical(parsed$schema, "two_column")) {
        "deprecated two-column schema"
      } else if (identical(gsub(", ", ",", header_clean), std)) {
        "space-padded column names in the header"
      } else if (grepl('""', header_clean, fixed = TRUE) &&
                 identical(gsub('"', "", header_clean), std)) {
        "doubly quoted column names in the header"
      } else if (identical(gsub('"', "", header_clean), std)) {
        "quoted column names in the header"
      } else if (identical(sub(",+$", "", header_clean), std)) {
        "trailing empty columns in the header"
      } else {
        paste0("nonstandard header: ", substr(header_clean, 1, 80))
      }
      add(repo, "data-raw/dictionary.csv", kind,
          "Regenerate with the current washr template (five clean columns)")
    }
  }
} else {
  message("OWD_LOCAL_ROOT not set; skipping clone-level checks (encoding, headers, lfs)")
}

# --- merge harvest_report problems ------------------------------------------

if (file.exists("data-raw/harvest_report.md")) {
  rep <- readLines("data-raw/harvest_report.md")
  probs <- grep("^- .+ \\[(warn|fatal)\\]: ", rep, value = TRUE)
  for (line in probs) {
    m <- regmatches(line, regexec("^- (\\S+) \\[(warn|fatal)\\]: (.*)$", line))[[1]]
    reason <- m[4]
    # Skip reasons already covered by structured checks above.
    if (grepl("version drift", reason)) next
    file <- if (grepl("version", reason)) "DESCRIPTION" else if (grepl("URL", reason)) "DESCRIPTION" else "(see reason)"
    fix <- if (grepl("normalized malformed version", reason)) {
      "Remove the leading v from the Version field"
    } else if (grepl("URL", reason)) {
      "Point the URL field at the package repository"
    } else {
      "See the harvest report"
    }
    add(m[2], file, reason, fix)
  }
}

# --- write ------------------------------------------------------------------

fixes <- do.call(rbind, fixes)
fixes <- fixes[order(fixes$repo, fixes$file), ]
fixes <- fixes[!duplicated(fixes[, c("repo", "defect")]), ]

lines <- c(
  "# Upstream fixes for the data repositories",
  "",
  paste0(
    "Generated by data-raw/upstream_fixes.R from the harvest of ",
    format(owd_catalog$meta$harvest_date),
    ". Each row is a defect in a data package repository that the owdata"
  ),
  "harvester tolerates but that should be fixed at the source. This list",
  "seeds the migration campaign (openwashdata/owdata#10); regenerate it",
  "after each harvest and delete rows as upstream PRs merge.",
  "",
  "Every fix is an author-side change; announce the campaign to",
  "maintainers before opening scripted PRs (see the premortem notes on",
  "issue #10).",
  "",
  sprintf("%d defects across %d repositories.", nrow(fixes), length(unique(fixes$repo))),
  ""
)
for (repo in unique(fixes$repo)) {
  sub <- fixes[fixes$repo == repo, ]
  lines <- c(lines, paste0("## ", repo), "")
  for (i in seq_len(nrow(sub))) {
    lines <- c(lines, sprintf("- `%s`: %s. Fix: %s.", sub$file[i], sub$defect[i], sub$fix[i]))
  }
  lines <- c(lines, "")
}
writeLines(lines, "data-raw/upstream_fixes.md")
message("Wrote data-raw/upstream_fixes.md: ", nrow(fixes), " defects in ",
        length(unique(fixes$repo)), " repos")
