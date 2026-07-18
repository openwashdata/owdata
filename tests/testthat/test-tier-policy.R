test_that("tier boundaries assign dev, candidate, and catalogued", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$assign_tier(
    version = c("0.0.0.9000", "0.0.1", "0.1.0", "0.9.9", "1.0.0", "1.0.0"),
    doi = c(NA, NA, NA, NA, "10.5281/zenodo.12345", NA)
  )
  expect_equal(
    as.character(out$tier),
    c("dev", "dev", "candidate", "candidate", "catalogued", "candidate")
  )
  expect_equal(out$legacy, c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE))
})

test_that("grandfather rule marks DOI-holding sub-1.0.0 packages legacy", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$assign_tier(
    version = c("0.5.0", "0.0.1"),
    doi = c("10.5281/zenodo.111", "10.5281/zenodo.222")
  )
  expect_equal(as.character(out$tier), c("catalogued", "catalogued"))
  expect_true(all(out$legacy))
})

test_that("non-Zenodo DOIs do not count toward catalogued", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$assign_tier("1.2.0", "10.1000/other.doi")
  expect_equal(as.character(out$tier), "candidate")
})

test_that("a leading v is stripped before parsing", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  expect_equal(e$normalize_version("v1.0.0"), "1.0.0")
  out <- e$assign_tier("v1.0.0", "10.5281/zenodo.999")
  expect_equal(as.character(out$tier), "catalogued")
})

test_that("unparseable versions come back as NA tier, not an error", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$assign_tier(c("not.a.version", NA), c(NA, NA))
  expect_true(all(is.na(out$tier)))
})

test_that("tier overrides replace the mechanical tier and clear legacy", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  tiers <- e$assign_tier(c("0.5.0", "0.0.1"), c("10.5281/zenodo.1", NA))
  overrides <- data.frame(
    pkg_name = "pkga", tier = "dev", reason = "withdrawn from catalog",
    stringsAsFactors = FALSE
  )
  out <- e$apply_tier_overrides(c("pkga", "pkgb"), tiers, overrides)
  expect_equal(as.character(out$tier), c("dev", "dev"))
  expect_false(out$legacy[[1]])

  bad <- data.frame(pkg_name = "pkga", tier = "gold", reason = "x")
  expect_error(
    e$apply_tier_overrides(c("pkga"), tiers[1, ], bad),
    "Unknown tier"
  )
})
