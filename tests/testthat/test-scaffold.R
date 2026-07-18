test_that("package version is a valid R package version", {
  expect_no_error(package_version(as.character(utils::packageVersion("owdata"))))
})
