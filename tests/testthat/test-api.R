test_that("owd_packages filters by tier", {
  all <- owd_packages()
  cat <- owd_packages(tier = "catalogued")
  expect_true(all(cat$tier == "catalogued"))
  both <- owd_packages(tier = c("catalogued", "candidate"))
  expect_true(all(both$tier %in% c("catalogued", "candidate")))
  expect_lte(nrow(both), nrow(all))
  expect_error(owd_packages(tier = "published"), "arg")
})

test_that("owd_datasets and owd_variables filter and validate pkg", {
  ds <- owd_datasets()
  some_pkg <- ds$pkg_name[1]
  expect_true(all(owd_datasets(pkg = some_pkg)$pkg_name == some_pkg))
  expect_error(owd_datasets(pkg = "definitely-not-a-package"), "Not in the openwashdata catalog")

  vr <- owd_variables(pkg = some_pkg)
  expect_true(all(vr$pkg_name == some_pkg))
  some_ds <- ds$dataset_name[1]
  vr2 <- owd_variables(dataset = some_ds)
  expect_true(all(vr2$dataset_name == some_ds))
})

test_that("owd_search finds known terms and respects fields", {
  hits <- owd_search("water")
  expect_s3_class(hits, "tbl_df")
  expect_gt(nrow(hits), 0)
  expect_equal(
    names(hits),
    c("pkg_name", "match_type", "dataset_name", "field", "text")
  )
  expect_true(all(grepl("water", hits$text, ignore.case = TRUE)))

  vars_only <- owd_search("water", fields = "variable_name")
  expect_true(all(vars_only$match_type == "variable"))
  expect_true(all(vars_only$field == "variable_name"))

  expect_equal(nrow(owd_search("zz-no-such-term-zz")), 0)
})

test_that("owd_search validates its inputs", {
  expect_error(owd_search(""), "non-empty")
  expect_error(owd_search(NA_character_), "non-empty")
  expect_error(owd_search(c("a", "b")), "non-empty")
  expect_error(owd_search("("), "Invalid regular expression")
  expect_error(owd_search("water", fields = "nope"), "arg")
})

test_that("owd_install validates without touching the network", {
  expect_error(owd_install(character()), "character vector")
  expect_error(owd_install("definitely-not-a-package"), "Not in the openwashdata catalog")
  # Non-interactive sessions must name packages explicitly.
  expect_error(owd_install(), "explicitly")
})

test_that("the startup message summarizes the catalog and flags staleness", {
  msg <- owd_startup_message()
  expect_match(msg, "owdata catalog: \\d+ catalogued, \\d+ candidate, \\d+ in development")
  expect_match(msg, "owd_search")

  old <- owd_startup_message(today = owd_active_catalog()$meta$harvest_date + 100)
  expect_match(old, "owd_refresh")
  fresh <- owd_startup_message(today = owd_active_catalog()$meta$harvest_date + 7)
  expect_no_match(fresh, "owd_refresh\\(\\) for the latest")
})
