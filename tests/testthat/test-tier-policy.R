test_that("version normalization strips a leading v and trims", {
  expect_equal(owd_normalize_version("v1.0.0"), "1.0.0")
  expect_equal(owd_normalize_version("V2.1.0"), "2.1.0")
  expect_equal(owd_normalize_version(" 0.1.0 "), "0.1.0")
  expect_equal(owd_normalize_version(""), NA_character_)
  expect_equal(owd_normalize_version(NA), NA_character_)
})

test_that("tier boundaries follow the policy table", {
  res <- owd_assign_tier(
    version = c("0.0.0.9000", "0.0.1", "0.0.2", "0.1.0", "0.2.0", "0.9.9", "1.0.0", "1.1.0"),
    doi = c(NA, NA, NA, NA, NA, NA, "10.5281/zenodo.1", "10.5281/zenodo.2")
  )
  expect_equal(
    as.character(res$tier),
    c("dev", "dev", "dev", "candidate", "candidate", "candidate", "catalogued", "catalogued")
  )
  expect_false(any(res$legacy))
})

test_that("1.0.0 without a Zenodo DOI is candidate, not catalogued", {
  res <- owd_assign_tier("1.0.0", NA_character_)
  expect_equal(as.character(res$tier), "candidate")
  res <- owd_assign_tier("1.0.0", "10.1234/other.doi")
  expect_equal(as.character(res$tier), "candidate")
})

test_that("grandfather rule: DOI below 1.0.0 is catalogued with legacy flag", {
  res <- owd_assign_tier(c("0.0.1", "0.1.0"), c("10.5281/zenodo.8208417", "10.5281/zenodo.1"))
  expect_equal(as.character(res$tier), c("catalogued", "catalogued"))
  expect_true(all(res$legacy))
})

test_that("malformed versions normalize or fall back to dev", {
  res <- owd_assign_tier("v1.0.0", "10.5281/zenodo.1")
  expect_equal(as.character(res$tier), "catalogued")
  expect_false(res$legacy)

  res <- owd_assign_tier(c("not-a-version", NA), c(NA, NA))
  expect_equal(as.character(res$tier), c("dev", "dev"))
})

test_that("tier overrides replace the mechanical assignment", {
  tiers <- owd_assign_tier(c("0.1.0", "1.0.0"), c(NA, "10.5281/zenodo.1"))
  overrides <- data.frame(
    pkg_name = "pkg_a", tier = "dev", reason = "withdrawn by maintainer"
  )
  out <- owd_apply_tier_overrides(tiers, c("pkg_a", "pkg_b"), overrides)
  expect_equal(as.character(out$tier), c("dev", "catalogued"))

  empty <- utils::read.csv(
    text = "pkg_name,tier,reason\n", colClasses = "character"
  )
  expect_equal(owd_apply_tier_overrides(tiers, c("pkg_a", "pkg_b"), empty), tiers)

  bad <- data.frame(pkg_name = "pkg_a", tier = "gold", reason = "typo")
  expect_error(owd_apply_tier_overrides(tiers, "pkg_a", bad), "Unknown tier")
})
