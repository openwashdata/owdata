# The r-universe registry draft (#8).
#
# A custom registry supersedes the auto-generated CRAN one, so the moment
# openwashdata.r-universe.dev holds a packages.json, that file is the
# whole universe. washr appears there today only because of the
# auto-generated registry, so a generated file that ever omitted it would
# silently drop washr from the universe. Hence the hard-coding, and hence
# this test.

registry_path <- testthat::test_path("..", "..", "data-raw", "packages.json")

test_that("the registry draft names washr and owdata", {
  skip_if_not(file.exists(registry_path), "packages.json not generated yet")
  registry <- jsonlite::fromJSON(registry_path, simplifyDataFrame = FALSE)
  names <- vapply(registry, function(e) e$package, character(1))
  expect_true("washr" %in% names)
  expect_true("owdata" %in% names)
})

test_that("every registry entry is a well formed org URL, listed once, sorted", {
  skip_if_not(file.exists(registry_path), "packages.json not generated yet")
  registry <- jsonlite::fromJSON(registry_path, simplifyDataFrame = FALSE)
  names <- vapply(registry, function(e) e$package, character(1))
  urls <- vapply(registry, function(e) e$url, character(1))
  expect_equal(urls, paste0("https://github.com/openwashdata/", names))
  expect_false(any(duplicated(names)))
  expect_equal(names, sort(names))
})

test_that("the registry lists published packages, and no unpublished one", {
  skip_if_not(file.exists(registry_path), "packages.json not generated yet")
  registry <- jsonlite::fromJSON(registry_path, simplifyDataFrame = FALSE)
  names <- vapply(registry, function(e) e$package, character(1))
  pkgs <- owd_active_catalog()$packages
  expect_true(all(pkgs$pkg_name[pkgs$published] %in% names))
  # The two tools are in the registry without being catalog entries.
  unpublished <- setdiff(names, c("washr", "owdata"))
  expect_false(any(pkgs$pkg_name[!pkgs$published] %in% unpublished))
})
