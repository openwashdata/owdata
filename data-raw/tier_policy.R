# Single source of truth for catalog tier assignment (issue #2).
#
# Pure functions: version string plus DOI in, tier plus legacy flag out.
# Unit tested in tests/testthat/test-tier-policy.R; those tests are
# skipped under R CMD check because data-raw/ is not part of the built
# package.
#
# Policy:
#   dev        version below 0.1.0 (0.0.x, 0.0.0.9000)
#   candidate  0.1.0 <= version < 1.0.0, or >= 1.0.0 without a Zenodo DOI
#   catalogued version >= 1.0.0 AND a Zenodo DOI in CITATION.cff
#
# Transitional grandfather rule (dated): a Zenodo DOI with a version
# below 1.0.0 counts as catalogued with legacy = TRUE. Remove per
# package as reviews plus 1.0.0 bumps land (issue #10); delete the rule
# when the migration campaign completes.

POLICY_VERSION <- "1"
GRANDFATHER_RULE_DATE <- as.Date("2026-07-08")
ZENODO_DOI_PATTERN <- "^10\\.5281/zenodo\\."

TIER_LEVELS <- c("dev", "candidate", "catalogued")

# Strip a leading v or V before parsing (fixes waterpointstatus, which
# has Version: v1.0.0).
normalize_version <- function(x) {
  x <- ifelse(is.na(x), NA_character_, trimws(x))
  sub("^[vV]", "", x)
}

# package_version() that returns NA instead of erroring on malformed
# input, vectorized.
parse_version_safe <- function(x) {
  x <- normalize_version(x)
  lapply(x, function(v) {
    if (is.na(v) || !nzchar(v)) {
      return(NA)
    }
    tryCatch(package_version(v), error = function(e) NA)
  })
}

is_zenodo_doi <- function(doi) {
  !is.na(doi) & grepl(ZENODO_DOI_PATTERN, trimws(doi))
}

# Vectorized tier assignment. Returns a data.frame with columns
# tier (factor over TIER_LEVELS) and legacy (logical). Unparseable
# versions come back as tier NA so the harvester can route the package
# to the problems tibble rather than mis-tier it.
assign_tier <- function(version, doi) {
  stopifnot(length(version) == length(doi))
  parsed <- parse_version_safe(version)
  zenodo <- is_zenodo_doi(doi)

  tier <- character(length(version))
  legacy <- logical(length(version))

  for (i in seq_along(version)) {
    v <- parsed[[i]]
    if (length(v) == 1 && is.na(v)) {
      tier[i] <- NA_character_
      legacy[i] <- NA
      next
    }
    if (v >= "1.0.0") {
      tier[i] <- if (zenodo[i]) "catalogued" else "candidate"
    } else if (v >= "0.1.0") {
      if (zenodo[i]) {
        tier[i] <- "catalogued"
        legacy[i] <- TRUE
      } else {
        tier[i] <- "candidate"
      }
    } else {
      if (zenodo[i]) {
        tier[i] <- "catalogued"
        legacy[i] <- TRUE
      } else {
        tier[i] <- "dev"
      }
    }
  }

  data.frame(
    tier = factor(tier, levels = TIER_LEVELS),
    legacy = legacy,
    stringsAsFactors = FALSE
  )
}

# Escape hatch (issue #2): data-raw/tier_overrides.csv with columns
# pkg_name, tier, reason. Kept near-empty. An override replaces the
# mechanical tier and clears the legacy flag; an unknown tier value in
# the file is an error, not a silent fallthrough.
apply_tier_overrides <- function(pkg_name, tiers, overrides) {
  stopifnot(is.data.frame(tiers), nrow(tiers) == length(pkg_name))
  if (is.null(overrides) || nrow(overrides) == 0) {
    return(tiers)
  }
  bad <- setdiff(overrides$tier, TIER_LEVELS)
  if (length(bad) > 0) {
    stop("Unknown tier value in tier_overrides.csv: ", paste(bad, collapse = ", "))
  }
  idx <- match(pkg_name, overrides$pkg_name)
  hit <- !is.na(idx)
  tiers$tier[hit] <- factor(overrides$tier[idx[hit]], levels = TIER_LEVELS)
  tiers$legacy[hit] <- FALSE
  tiers
}

read_tier_overrides <- function(path = file.path("data-raw", "tier_overrides.csv")) {
  if (!file.exists(path)) {
    return(data.frame(
      pkg_name = character(), tier = character(), reason = character(),
      stringsAsFactors = FALSE
    ))
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}
