# Version-tier inclusion policy for the openwashdata catalog.
#
# Single source of truth for how a package's version string and Zenodo DOI
# map to a catalog tier. Used by the harvest orchestrator in data-raw/ and
# unit tested in tests/testthat/test-tier-policy.R. The functions are pure:
# no network access, no side effects.

owd_policy_version <- function() "2026.1"

#' Normalize a DESCRIPTION version string
#'
#' Strips a leading "v" or "V" (fixes waterpointstatus, which shipped
#' Version: v1.0.0) and trims whitespace. Returns NA for empty input.
#'
#' @param version Character vector of raw version strings.
#' @return Character vector of normalized version strings.
#' @keywords internal
#' @noRd
owd_normalize_version <- function(version) {
  v <- trimws(as.character(version))
  v <- sub("^[vV]", "", v)
  v[is.na(v) | !nzchar(v)] <- NA_character_
  v
}

# TRUE where the normalized version string parses as a numeric version.
owd_version_is_valid <- function(version) {
  !is.na(version) & grepl("^[0-9]+([.-][0-9]+)+$", version)
}

# TRUE where the DOI is a Zenodo DOI (10.5281/zenodo.*).
owd_is_zenodo_doi <- function(doi) {
  !is.na(doi) & grepl("^10\\.5281/zenodo\\.", doi)
}

#' Assign catalog tiers from version strings and DOIs
#'
#' Policy (see the versioning-policy article):
#'
#' - dev: version below 0.1.0, or unparseable
#' - candidate: 0.1.0 <= version < 1.0.0 (bumping to 0.1.0 is the review
#'   request), and also version >= 1.0.0 without a Zenodo DOI (awaiting DOI)
#' - catalogued: version >= 1.0.0 and a Zenodo DOI in CITATION.cff
#'
#' Transitional grandfather rule (added 2026-07, tracked in
#' openwashdata/owdata#10): a Zenodo DOI with version < 1.0.0 counts as
#' catalogued with legacy = TRUE. These packages were published before the
#' 2026 review standard. Delete this rule when the migration campaign
#' completes.
#'
#' @param version Character vector of raw version strings.
#' @param doi Character vector of DOIs, NA where absent.
#' @return A data.frame with columns tier (factor with levels dev,
#'   candidate, catalogued) and legacy (logical).
#' @keywords internal
#' @noRd
owd_assign_tier <- function(version, doi) {
  stopifnot(length(version) == length(doi))
  v <- owd_normalize_version(version)
  valid <- owd_version_is_valid(v)
  pv <- numeric_version(ifelse(valid, v, "0.0.0"))
  has_doi <- owd_is_zenodo_doi(doi)

  tier <- rep("dev", length(v))
  legacy <- rep(FALSE, length(v))

  tier[valid & pv >= "0.1.0"] <- "candidate"
  tier[valid & pv >= "1.0.0" & has_doi] <- "catalogued"

  grandfathered <- valid & pv < "1.0.0" & has_doi
  tier[grandfathered] <- "catalogued"
  legacy[grandfathered] <- TRUE

  data.frame(
    tier = factor(tier, levels = owd_tier_levels()),
    legacy = legacy
  )
}

owd_tier_levels <- function() c("dev", "candidate", "catalogued")

#' Apply manual tier overrides from tier_overrides.csv
#'
#' Overrides are the escape hatch for packages the mechanical rule
#' misclassifies. The file is kept near-empty by design.
#'
#' @param tiers data.frame as returned by owd_assign_tier().
#' @param pkg_name Character vector aligned with tiers.
#' @param overrides data.frame with columns pkg_name, tier, reason.
#' @return tiers with overridden rows replaced.
#' @keywords internal
#' @noRd
owd_apply_tier_overrides <- function(tiers, pkg_name, overrides) {
  if (is.null(overrides) || nrow(overrides) == 0) {
    return(tiers)
  }
  bad <- setdiff(overrides$tier, owd_tier_levels())
  if (length(bad) > 0) {
    stop("Unknown tier in tier_overrides.csv: ", paste(bad, collapse = ", "))
  }
  idx <- match(pkg_name, overrides$pkg_name)
  hit <- !is.na(idx)
  tiers$tier[hit] <- factor(overrides$tier[idx[hit]], levels = owd_tier_levels())
  tiers$legacy[hit] <- FALSE
  tiers
}
