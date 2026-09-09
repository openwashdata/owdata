# One behavioural test per export. Every expect_error() names its
# message, as CLAUDE.md requires.

test_that("owd_packages filters on the published flag", {
  all_pkgs <- owd_packages()
  pub <- owd_packages(published = TRUE)
  unpub <- owd_packages(published = FALSE)
  expect_gt(nrow(all_pkgs), 0)
  expect_equal(nrow(pub) + nrow(unpub), nrow(all_pkgs))
  expect_true(all(pub$published))
  expect_false(any(unpub$published))
})

test_that("owd_packages rejects a non-logical published argument", {
  expect_error(owd_packages(published = "yes"), "must be TRUE, FALSE or NULL")
  expect_error(owd_packages(published = NA), "must be TRUE, FALSE or NULL")
  expect_error(owd_packages(published = c(TRUE, FALSE)), "must be TRUE, FALSE or NULL")
})

test_that("owd_datasets filters by package", {
  d <- owd_datasets()
  skip_if(nrow(d) == 0, "no published packages in this catalog")
  one <- d$pkg_name[1]
  expect_true(all(owd_datasets(pkg = one)$pkg_name == one))
})

test_that("owd_datasets rejects an unknown package", {
  expect_error(owd_datasets(pkg = "not-a-package"), "Not in the openwashdata catalog")
})

test_that("owd_variables filters by package and dataset", {
  v <- owd_variables()
  skip_if(nrow(v) == 0, "no published packages in this catalog")
  one <- v$pkg_name[1]
  sub <- owd_variables(pkg = one)
  expect_true(all(sub$pkg_name == one))
  ds <- sub$dataset_name[!is.na(sub$dataset_name)][1]
  skip_if(is.na(ds), "no attributed dataset name")
  expect_true(all(owd_variables(pkg = one, dataset = ds)$dataset_name == ds))
})

test_that("owd_variables rejects an unknown package", {
  expect_error(owd_variables(pkg = "not-a-package"), "Not in the openwashdata catalog")
})

test_that("owd_search finds hits for the terms the catalog is built for", {
  for (query in c("groundwater", "sanitation")) {
    hits <- owd_search(query)
    expect_gt(nrow(hits), 0)
    expect_true(all(hits$match_type %in% c("package", "dataset", "variable")))
    expect_true(all(grepl(query, hits$text, ignore.case = TRUE)))
  }
})

test_that("owd_search is case insensitive and honours the fields argument", {
  expect_equal(nrow(owd_search("WATER")), nrow(owd_search("water")))
  hits <- owd_search("water", fields = "variable_name")
  expect_true(all(hits$field == "variable_name"))
})

test_that("owd_search returns zero rows rather than failing on no match", {
  hits <- owd_search("zzzznotpresentanywhere")
  expect_s3_class(hits, "tbl_df")
  expect_equal(nrow(hits), 0)
})

test_that("owd_search rejects an empty or malformed query", {
  expect_error(owd_search(""), "must be a single non-empty string")
  expect_error(owd_search(NA_character_), "must be a single non-empty string")
  expect_error(owd_search(c("a", "b")), "must be a single non-empty string")
  expect_error(owd_search("("), "Invalid regular expression")
})

test_that("owd_install refuses an unknown package and never installs in tests", {
  expect_error(owd_install("not-a-package"), "Not in the openwashdata catalog")
  expect_error(owd_install(character()), "must be a character vector")
})

test_that("owd_install refuses pkg = NULL in a non-interactive session", {
  skip_if(interactive(), "interactive session would prompt")
  expect_error(owd_install(), "Name packages explicitly in scripts")
})

test_that("the startup message names the counts and the harvest date", {
  msg <- owd_startup_message()
  cat <- owd_active_catalog()
  expect_match(msg, "^owdata catalog: ")
  expect_match(msg, format(cat$meta$harvest_date), fixed = TRUE)
  expect_match(msg, "owd_search\\(\\)")
})
