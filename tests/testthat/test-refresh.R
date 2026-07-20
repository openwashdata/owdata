test_that("owd_refresh installs a valid catalog into the cache", {
  cache_dir <- withr::local_tempdir()
  withr::local_envvar(OWD_CACHE_DIR = cache_dir)
  withr::defer(owd_forget_catalog())
  owd_forget_catalog()

  json <- system.file("extdata", "catalog.json", package = "owdata")
  expect_true(nzchar(json))
  expect_true(owd_refresh(url = json, quiet = TRUE))
  expect_true(file.exists(file.path(cache_dir, "catalog.rds")))

  active <- owd_active_catalog()
  expect_true(owd_is_catalog(active))
  expect_gt(nrow(owd_packages()), 0)
})

test_that("a corrupt cache falls back to the installed snapshot", {
  cache_dir <- withr::local_tempdir()
  withr::local_envvar(OWD_CACHE_DIR = cache_dir)
  withr::defer(owd_forget_catalog())
  owd_forget_catalog()

  writeLines("garbage", file.path(cache_dir, "catalog.rds"))
  active <- owd_active_catalog()
  expect_true(owd_is_catalog(active))
  expect_equal(
    active$meta$harvest_date,
    owd_installed_catalog()$meta$harvest_date
  )
})

test_that("a failed download keeps the installed snapshot and returns FALSE", {
  cache_dir <- withr::local_tempdir()
  withr::local_envvar(OWD_CACHE_DIR = cache_dir)
  withr::defer(owd_forget_catalog())
  owd_forget_catalog()

  expect_false(suppressWarnings(
    owd_refresh(url = "file:///no/such/path/catalog.json", quiet = TRUE)
  ))
  expect_false(file.exists(file.path(cache_dir, "catalog.rds")))
  expect_true(owd_is_catalog(owd_active_catalog()))
})

test_that("an invalid downloaded bundle is rejected", {
  cache_dir <- withr::local_tempdir()
  withr::local_envvar(OWD_CACHE_DIR = cache_dir)
  withr::defer(owd_forget_catalog())
  owd_forget_catalog()

  bad <- withr::local_tempfile(fileext = ".json")
  writeLines("{\"not\": \"a catalog\"}", bad)
  expect_false(owd_refresh(url = bad, quiet = TRUE))
  expect_false(file.exists(file.path(cache_dir, "catalog.rds")))
})
