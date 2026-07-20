# Schema and content gates for the shipped catalog. These tests are the
# gate the weekly harvest must pass before its commit reaches main.

pk <- owd_packages()
ds <- owd_datasets()
vr <- owd_variables()

test_that("owd_packages has the documented schema and is non-empty", {
  expect_s3_class(pk, "tbl_df")
  expect_gt(nrow(pk), 0)
  expect_equal(
    names(pk),
    c(
      "pkg_name", "title", "description", "version", "tier", "legacy",
      "maintainer", "maintainer_orcid", "authors", "license", "date",
      "doi", "cff_version", "url_github", "url_docs", "n_datasets",
      "latest_release", "default_branch", "created_at", "last_commit",
      "topics", "has_dictionary", "has_extdata"
    )
  )
  expect_type(pk$pkg_name, "character")
  expect_s3_class(pk$tier, "factor")
  expect_equal(levels(pk$tier), c("dev", "candidate", "catalogued"))
  expect_type(pk$legacy, "logical")
  expect_s3_class(pk$date, "Date")
  expect_s3_class(pk$created_at, "Date")
  expect_s3_class(pk$last_commit, "Date")
  expect_type(pk$n_datasets, "integer")
  expect_type(pk$has_dictionary, "logical")
  expect_type(pk$has_extdata, "logical")
})

test_that("owd_datasets has the documented schema and is non-empty", {
  expect_s3_class(ds, "tbl_df")
  expect_gt(nrow(ds), 0)
  expect_equal(
    names(ds),
    c(
      "pkg_name", "dataset_name", "title", "description", "n_rows",
      "n_vars", "n_vars_dictionary", "csv_url", "xlsx_url"
    )
  )
  expect_type(ds$n_rows, "integer")
  expect_type(ds$n_vars, "integer")
  expect_type(ds$n_vars_dictionary, "integer")
})

test_that("owd_variables has the documented schema and is non-empty", {
  expect_s3_class(vr, "tbl_df")
  expect_gt(nrow(vr), 0)
  expect_equal(
    names(vr),
    c("pkg_name", "dataset_name", "variable_name", "variable_type", "description")
  )
  expect_false(any(is.na(vr$variable_name)))
})

test_that("content gates: tiers, DOIs and keys are coherent", {
  expect_false(any(is.na(pk$tier)))
  expect_false(any(duplicated(pk$pkg_name)))
  expect_false(any(is.na(pk$pkg_name)))

  catalogued <- pk[pk$tier == "catalogued", ]
  expect_true(all(!is.na(catalogued$doi)))
  expect_true(all(grepl("^10\\.5281/zenodo\\.", catalogued$doi)))

  legacy <- pk[pk$legacy, ]
  expect_true(all(legacy$tier == "catalogued"))

  detail_pkgs <- pk$pkg_name[pk$tier %in% c("candidate", "catalogued")]
  expect_true(all(ds$pkg_name %in% detail_pkgs))
  expect_true(all(vr$pkg_name %in% detail_pkgs))
  expect_false(any(duplicated(paste(ds$pkg_name, ds$dataset_name))))
})

test_that("the search index covers all three tables", {
  idx <- owd_active_catalog()$index
  expect_gt(nrow(idx), 0)
  expect_setequal(unique(idx$match_type), c("package", "dataset", "variable"))
  expect_true(all(idx$pkg_name %in% pk$pkg_name))
  expect_false(any(is.na(idx$text)))
})

test_that("catalog metadata is present and dated", {
  meta <- owd_active_catalog()$meta
  expect_s3_class(meta$harvest_date, "Date")
  expect_true(meta$harvest_date <= Sys.Date())
  expect_type(meta$policy_version, "character")
})

test_that("catalog.json ships and round-trips to the same tables", {
  path <- system.file("extdata", "catalog.json", package = "owdata")
  expect_true(nzchar(path))
  round <- owd_read_catalog_json(path)
  expect_true(owd_is_catalog(round))
  expect_equal(nrow(round$packages), nrow(pk))
  expect_equal(round$packages$pkg_name, pk$pkg_name)
  expect_equal(as.character(round$packages$tier), as.character(pk$tier))
  expect_equal(round$packages$doi, pk$doi)
  expect_equal(round$packages$date, pk$date)
  expect_equal(nrow(round$datasets), nrow(ds))
  expect_equal(round$datasets$n_rows, ds$n_rows)
  expect_equal(nrow(round$variables), nrow(vr))
  expect_equal(round$meta$harvest_date, owd_active_catalog()$meta$harvest_date)
})

test_that("CSV exports ship for all three tables", {
  for (name in c("owd_packages", "owd_datasets", "owd_variables")) {
    path <- system.file("extdata", paste0(name, ".csv"), package = "owdata")
    expect_true(nzchar(path), info = name)
  }
  csv <- utils::read.csv(
    system.file("extdata", "owd_packages.csv", package = "owdata"),
    colClasses = "character"
  )
  expect_equal(nrow(csv), nrow(pk))
  expect_equal(names(csv), names(pk))
})
