test_that("washr and owdata are in the registry by construction", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  entries <- e$make_registry(character(0))
  pkgs <- vapply(entries, function(x) x$package, character(1))
  expect_true(all(c("washr", "owdata") %in% pkgs))

  entries <- e$make_registry(c("washmalawi", "gdho", NA, ""))
  pkgs <- vapply(entries, function(x) x$package, character(1))
  expect_true(all(c("washr", "owdata", "washmalawi", "gdho") %in% pkgs))
  expect_false(any(is.na(pkgs) | pkgs == ""))
  urls <- vapply(entries, function(x) x$url, character(1))
  expect_true(all(startsWith(urls, "https://github.com/openwashdata/")))
})
